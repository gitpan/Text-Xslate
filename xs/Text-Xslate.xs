#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#define NEED_newSVpvn_flags
#include "ppport.h"

#define MY_CXT_KEY "Text::Xslate::_guts" XS_VERSION
typedef struct {
    U32 depth;
    HV* escaped_string_stash;
} my_cxt_t;
START_MY_CXT

#define TX_ESC_CLASS "Text::Xslate::EscapedString"

#define TXC(name) static void CAT2(TXCODE_, name)(pTHX_ tx_state_t* const txst)
/* TXC_xxx macros provide the information of arguments, interpreted by tool/opcode.pl */
#define TXC_w_sv(n)  TXC(n) /* has TX_op_arg as a SV */
#define TXC_w_int(n) TXC(n) /* has TX_op_arg as an integer (i.e. can SvIVX(arg)) */
#define TXC_w_key(n) TXC(n) /* has TX_op_arg as a keyword */
#define TXC_w_var(n) TXC(n) /* has TX_op_arg as a local variable */
#define TXC_goto(n)  TXC(n) /* does goto */

#define TXARGf_SV   ((U8)(0x01))
#define TXARGf_INT  ((U8)(0x02))
#define TXARGf_KEY  ((U8)(0x04))
#define TXARGf_VAR  ((U8)(0x08))
#define TXARGf_GOTO ((U8)(0x10))

#define TXCODE_W_SV  (TXARGf_SV)
#define TXCODE_W_INT (TXARGf_SV | TXARGf_INT)
#define TXCODE_W_VAR (TXARGf_SV | TXARGf_INT | TXARGf_VAR)
#define TXCODE_W_KEY (TXARGf_SV | TXARGf_KEY)
#define TXCODE_GOTO  (TXARGf_SV | TXARGf_INT | TXARGf_GOTO)

#define TX_st (txst)
#define TX_op (&(TX_st->code[TX_st->pc]))

#define TX_pop()   (*(PL_stack_sp--))

#define TX_current_framex(st) ((AV*)AvARRAY((st)->frame)[(st)->current_frame])
#define TX_current_frame()    TX_current_framex(TX_st)

enum txtmplo_ix {
    TXo_NAME,
    TXo_ERROR_HANDLER,
    TXo_MTIME,

    TXo_FULLPATH,
    /* dependencies here */
    TXo_least_size
};

enum txframeo_ix {
    TXframe_NAME,
    TXframe_OUTPUT,
    TXframe_RETADDR,

    TXframe_START_LVAR,
    /* local variables here */
    TXframe_least_size = TXframe_START_LVAR
};

struct tx_code_s;
struct tx_state_s;

typedef struct tx_code_s  tx_code_t;
typedef struct tx_state_s tx_state_t;

typedef void (*tx_exec_t)(pTHX_ tx_state_t* const);

struct tx_state_s {
    U32 pc;       /* the program counter */

    tx_code_t* code; /* compiled code */
    U32        code_len;

    SV* output;

    /* registers */

    SV* sa;
    SV* sb;
    SV* targ;

    /* variables */

    HV* vars;    /* template variables */

    /* stack frame */
    AV* frame;         /* see enum txframeo_ix */
    I32 current_frame; /* current frame index */
    SV** pad;          /* AvARRAY(frame[current_frame]) + 3 */

    HV* macro;    /* name -> $addr */
    HV* function; /* name => \&body */

    U32 hint_size; /* suggested template size (bytes) */

    AV* tmpl; /* see enum txtmplo_ix */
    SV* self;
    U16* lines;  /* code index -> line number */
};

struct tx_code_s {
    tx_exec_t exec_code;

    SV* arg;
};

#ifdef DEBUGGING
#define TX_st_sa  *tx_sv_safe(aTHX_ &(TX_st->sa),  "TX_st->sa",  __FILE__, __LINE__)
#define TX_st_sb  *tx_sv_safe(aTHX_ &(TX_st->sb),  "TX_st->sb",  __FILE__, __LINE__)
#define TX_op_arg *tx_sv_safe(aTHX_ &(TX_op->arg), "TX_st->arg", __FILE__, __LINE__)
static SV**
tx_sv_safe(pTHX_ SV** const svp, const char* const name, const char* const f, int const l) {
    if(UNLIKELY(*svp == NULL)) {
        croak("panic: %s is NULL at %s line %d.\n", name, f, l);
    }
    return svp;
}

#define TX_lvarx_get(st, ix) tx_lvar_get_safe(aTHX_ st, ix)

static SV*
tx_lvar_get_safe(pTHX_ tx_state_t* const st, I32 const lvar_ix) {
    AV* const cframe  = TX_current_framex(st);
    I32 const real_ix = lvar_ix + TXframe_START_LVAR;

    assert(SvTYPE(cframe) == SVt_PVAV);

    if(AvFILLp(cframe) < real_ix) {
        croak("panic: local variable storage is too small (%d < %d)",
            (int)(AvFILLp(cframe) - TXframe_START_LVAR), (int)lvar_ix); 
    }

    if(!st->pad) {
        croak("panic: access local variable (%d) before initialization",
            (int)lvar_ix);
    }
    return st->pad[lvar_ix];
}


#else /* DEBUGGING */
#define TX_st_sa        (TX_st->sa)
#define TX_st_sb        (TX_st->sb)
#define TX_op_arg       (TX_op->arg)

#define TX_lvarx_get(st, ix) ((st)->pad[ix])
#endif /* DEBUGGING */

#define TX_lvarx(st, ix) tx_fetch_lvar(aTHX_ st, ix)

#define TX_lvar(ix)     TX_lvarx(TX_st, ix)     /* init if uninitialized */
#define TX_lvar_get(ix) TX_lvarx_get(TX_st, ix)

/* aliases */
#define TXCODE_literal_i   TXCODE_literal
#define TXCODE_depend      TXCODE_noop

#include "xslate_ops.h"

static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv);

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name);

static const char*
tx_file(pTHX_ const tx_state_t* const st) {
    return SvPVx_nolen_const(*av_fetch(st->tmpl, TXo_NAME, TRUE));
}

static int
tx_line(pTHX_ const tx_state_t* const st) {
    return (int)st->lines[ st->pc ];
}

static const char*
tx_neat(pTHX_ SV* const sv) {
    if(SvOK(sv)) {
        if(SvROK(sv) || looks_like_number(sv)) {
            return form("%"SVf, sv);
        }
        else {
            return form("'%"SVf"'", sv);
        }
    }
    return "undef";
}

static SV*
tx_fetch_lvar(pTHX_ tx_state_t* const st, I32 const lvar_ix) { /* the guts of TX_lvar() */
    AV* const cframe  = TX_current_framex(st);
    I32 const real_ix = lvar_ix + TXframe_START_LVAR;

    assert(SvTYPE(cframe) == SVt_PVAV);

    if(AvFILLp(cframe) < real_ix) {
        av_store(cframe, real_ix, newSV(0));
    }
    st->pad = AvARRAY(cframe) + TXframe_START_LVAR;

    return TX_lvarx_get(st, lvar_ix);
}

static AV*
tx_push_frame(pTHX_ tx_state_t* const st) {
    AV* newframe;

    if(++st->current_frame > 100) {
        croak("Macro call is too deep (> 100)");
    }

    newframe = (AV*)*av_fetch(st->frame, st->current_frame, TRUE);

    SvUPGRADE((SV*)newframe, SVt_PVAV);
    if(AvFILLp(newframe) < TXframe_START_LVAR) {
        av_extend(newframe, TXframe_START_LVAR);
    }
    /* switch the pad */
    st->pad = AvARRAY(newframe) + TXframe_START_LVAR;
    return newframe;
}

static SV*
tx_call(pTHX_ tx_state_t* const st, SV* proc, I32 const flags, const char* const name) {
    ENTER;
    SAVETMPS;

    if(!(flags & G_METHOD)) {
        HV* dummy_stash;
        GV* dummy_gv;
        CV* const cv = sv_2cv(proc, &dummy_stash, &dummy_gv, FALSE);
        if(!cv) {
            croak("Functions must be a CODE reference, not %s",
                tx_neat(aTHX_ proc));
        }
        proc = (SV*)cv;
    }

    call_sv(proc, G_SCALAR | G_EVAL | flags);

    if(UNLIKELY(sv_true(ERRSV))){
        croak("%"SVf "\n"
            "\t... exception cought on %s", ERRSV, name);
    }

    sv_setsv_nomg(st->targ, TX_pop());

    FREETMPS;
    LEAVE;

    return st->targ;
}

static SV*
tx_fetch(pTHX_ tx_state_t* const st, SV* const var, SV* const key) {
    SV* sv = NULL;
    PERL_UNUSED_ARG(st);
    if(sv_isobject(var)) { /* sv_isobject() invokes SvGETMAGIC */
        dSP;
        PUSHMARK(SP);
        XPUSHs(var);
        PUTBACK;

        sv = tx_call(aTHX_ st, key, G_METHOD, "accessor");
    }
    else if(SvROK(var)){
        SV* const rv = SvRV(var);
        if(SvTYPE(rv) == SVt_PVHV) {
            HE* const he = hv_fetch_ent((HV*)rv, key, FALSE, 0U);

            sv = he ? hv_iterval((HV*)rv, he) : &PL_sv_undef;
        }
        else if(SvTYPE(rv) == SVt_PVAV) {
            SV** const svp = av_fetch((AV*)rv, SvIV(key), FALSE);

            sv = svp ? *svp : &PL_sv_undef;
        }
        else {
            goto invalid_container;
        }
    }
    else {
        invalid_container:
        croak("Cannot access '%"SVf"' (%s is not a container)",
            key, tx_neat(aTHX_ var));
    }
    return sv;
}

static SV*
tx_escaped_string(pTHX_ SV* const str) {
    dMY_CXT;
    SV* const sv = sv_newmortal();
    sv_copypv(sv, str);
    return sv_2mortal(sv_bless(newRV_inc(sv), MY_CXT.escaped_string_stash));
}

static bool
tx_str_is_escaped(pTHX_ SV* const sv) {
    if(SvROK(sv) && SvOBJECT(SvRV(sv))) {
        dMY_CXT;
        if(!SvOK(SvRV(sv))) {
            croak("Cannot use escaped string: not a reference to a string");
        }
        return SvSTASH(SvRV(sv)) == MY_CXT.escaped_string_stash;
    }
    return FALSE;
}

TXC(noop) {
    TX_st->pc++;
}

TXC(move_sa_to_sb) {
    TX_st_sb = TX_st_sa;

    TX_st->pc++;
}

TXC_w_var(store_to_lvar) {
    sv_setsv(TX_lvar(SvIVX(TX_op_arg)), TX_st_sa);
    TX_st->pc++;
}

TXC_w_var(load_lvar_to_sb) {
    TX_st_sb = TX_lvar_get(SvIVX(TX_op_arg));
    TX_st->pc++;
}

TXC(push) {
    dSP;
    XPUSHs(TX_st_sa);
    PUTBACK;

    TX_st->pc++;
}

TXC(pop) {
    TX_st_sa = TX_pop();

    TX_st->pc++;
}

TXC(pushmark) {
    dSP;
    PUSHMARK(SP);

    TX_st->pc++;
}

TXC(nil) {
    TX_st_sa = &PL_sv_undef;

    TX_st->pc++;
}

TXC_w_sv(literal) {
    TX_st_sa = TX_op_arg;

    TX_st->pc++;
}

/* the same as literal, but make sure its argument is an integer */
TXC_w_int(literal_i);

TXC_w_key(fetch_s) { /* fetch a field from the top */
    HV* const vars = TX_st->vars;
    HE* const he   = hv_fetch_ent(vars, TX_op_arg, FALSE, 0U);

    TX_st_sa = LIKELY(he != NULL) ? hv_iterval(vars, he) : &PL_sv_undef;

    TX_st->pc++;
}

TXC_w_var(fetch_lvar) {
    IV const id      = SvIVX(TX_op_arg);
    AV* const cframe = TX_current_frame();

    /* XXX: is there a better way? */
    if(AvFILLp(cframe) < (id + TXframe_START_LVAR)) {
        croak("Too few arguments for %"SVf, AvARRAY(cframe)[TXframe_NAME]);
    }

    TX_st_sa = TX_lvar_get(id);

    TX_st->pc++;
}

TXC(fetch_field) { /* fetch a field from a variable (bin operator) */
    SV* const var = TX_st_sb;
    SV* const key = TX_st_sa;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

TXC_w_key(fetch_field_s) { /* fetch a field from a variable (for literal) */
    SV* const var = TX_st_sa;
    SV* const key = TX_op_arg;

    TX_st_sa = tx_fetch(aTHX_ TX_st, var, key);
    TX_st->pc++;
}

TXC(print) {
    SV* const sv          = TX_st_sa;
    SV* const output      = TX_st->output;

    if(SvNIOK(sv) && !SvPOK(sv)){
        sv_catsv_nomg(output, sv);
    }
    else if(tx_str_is_escaped(aTHX_ sv)) {
        sv_catsv_nomg(output, SvRV(sv));
    }
    else {
        STRLEN len;
        const char*       cur = SvPV_const(sv, len);
        const char* const end = cur + len;

        (void)SvGROW(output, SvCUR(output) + len);

        while(cur != end) {
            const char* parts;
            STRLEN      parts_len;

            switch(*cur) {
            case '<':
                parts     =        "&lt;";
                parts_len = sizeof("&lt;") - 1;
                break;
            case '>':
                parts     =        "&gt;";
                parts_len = sizeof("&gt;") - 1;
                break;
            case '&':
                parts     =        "&amp;";
                parts_len = sizeof("&amp;") - 1;
                break;
            case '"':
                parts     =        "&quot;";
                parts_len = sizeof("&quot;") - 1;
                break;
            case '\'':
                parts     =        "&#39;";
                parts_len = sizeof("&#39;") - 1;
                break;
            default:
                parts     = cur;
                parts_len = 1;
                break;
            }

            len = SvCUR(output) + parts_len + 1;
            (void)SvGROW(output, len);

            if(LIKELY(parts_len == 1)) {
                *SvEND(output) = *parts;
            }
            else {
                Copy(parts, SvEND(output), parts_len, char);
            }
            SvCUR_set(output, SvCUR(output) + parts_len);

            cur++;
        }
        *SvEND(output) = '\0';
    }

    TX_st->pc++;
}

TXC(print_raw) {
    sv_catsv_nomg(TX_st->output, TX_st_sa);

    TX_st->pc++;
}

TXC_w_sv(print_raw_s) {
    sv_catsv_nomg(TX_st->output, TX_op_arg);

    TX_st->pc++;
}

TXC(include) {
    tx_state_t* const st = tx_load_template(aTHX_ TX_st->self, TX_st_sa);

    ENTER; /* for error handlers */
    tx_execute(aTHX_ st, TX_st->output, TX_st->vars);
    LEAVE;

    TX_st->pc++;
}


TXC_w_var(for_start) {
    SV* const avref = TX_st_sa;
    IV  const id    = SvIVX(TX_op_arg);

    SvGETMAGIC(avref);
    if(!(SvROK(avref) && SvTYPE(SvRV(avref)) == SVt_PVAV)) {
        croak("Iterator variables must be an ARRAY reference, not %s",
            tx_neat(aTHX_ avref));
    }

    (void)   TX_lvar(id+0); /* for each item, ensure to allocate a sv */
    sv_setsv(TX_lvar(id+1), avref);
    sv_setiv(TX_lvar(id+2), -1); /* (re)set iterator */

    TX_st->pc++;
}

TXC_goto(for_iter) {
    SV* const idsv  = TX_st_sa;
    IV  const id    = SvIVX(idsv); /* by literal_i */
    SV* const item  = TX_lvar_get(id+0);
    SV* const avref = TX_lvar_get(id+1);
    SV* const i     = TX_lvar_get(id+2);
    AV* const av    = (AV*)SvRV(avref);

    assert(SvTYPE(av) == SVt_PVAV);
    assert(SvIOK(i));

    //warn("for_next[%d %d]", (int)SvIV(i), (int)AvFILLp(av));
    if(LIKELY(SvRMAGICAL(av) == 0)) {
        if(LIKELY(++SvIVX(i) <= AvFILLp(av))) {
            sv_setsv(item, AvARRAY(av)[SvIVX(i)]);
            TX_st->pc++;
            return;
        }
    }
    else { /* magical variables */
        if(LIKELY(++SvIVX(i) <= av_len(av))) {
            SV** const itemp = av_fetch(av, SvIVX(i), FALSE);
            sv_setsv(item, itemp ? *itemp : &PL_sv_undef);
            TX_st->pc++;
            return;
        }
    }

    /* the loop finished */
    sv_setsv(item,  &PL_sv_undef);
    sv_setsv(avref, &PL_sv_undef);
    /* don't need to clear the iterator, it's only an integer */

    TX_st->pc = SvUVX(TX_op_arg); /* goto */
}


/* For arithmatic operators, SvIV_please() can make stringification faster,
   although I don't know why it is :)
*/
TXC(add) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) + SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(sub) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) - SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(mul) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) * SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(div) {
    sv_setnv(TX_st->targ, SvNVx(TX_st_sb) / SvNVx(TX_st_sa));
    sv_2iv(TX_st->targ); /* IV please */
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(mod) {
    sv_setiv(TX_st->targ, SvIVx(TX_st_sb) % SvIVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}

TXC_w_sv(concat) {
    SV* const sv = TX_op_arg;
    sv_setsv_nomg(sv, TX_st_sb);
    sv_catsv_nomg(sv, TX_st_sa);

    TX_st_sa = sv;

    TX_st->pc++;
}

TXC(filt) {
    SV* const arg    = TX_st_sb;
    SV* const filter = TX_st_sa;
    dSP;

    PUSHMARK(SP);
    XPUSHs(arg);
    PUTBACK;

    TX_st_sa = tx_call(aTHX_ TX_st, filter, 0, "filtering");

    TX_st->pc++;
}

TXC_goto(and) {
    if(sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC_goto(or) {
    if(!sv_true(TX_st_sa)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC_goto(dor) {
    SV* const sv = TX_st_sa;
    SvGETMAGIC(sv);
    if(!SvOK(sv)) {
        TX_st->pc++;
    }
    else {
        TX_st->pc = SvUVX(TX_op_arg);
    }
}

TXC(not) {
    TX_st_sa = boolSV( !sv_true(TX_st_sa) );

    TX_st->pc++;
}

TXC(plus) { /* unary plus */
    sv_setnv(TX_st->targ, +SvNVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}
TXC(minus) { /* unary minus */
    sv_setnv(TX_st->targ, -SvNVx(TX_st_sa));
    TX_st_sa = TX_st->targ;
    TX_st->pc++;
}


static I32
tx_sv_eq(pTHX_ SV* const a, SV* const b) {
    U32 const af = (SvFLAGS(a) & (SVf_POK|SVf_IOK|SVf_NOK));
    U32 const bf = (SvFLAGS(b) & (SVf_POK|SVf_IOK|SVf_NOK));

    if(af && bf) {
        if(af == SVf_IOK && bf == SVf_IOK) {
            return SvIVX(a) == SvIVX(b);
        }
        else {
            return sv_eq(a, b);
        }
    }

    SvGETMAGIC(a);
    SvGETMAGIC(b);

    if(SvOK(a)) {
        return SvOK(b) && sv_eq(a, b);
    }
    else { /* !SvOK(a) */
        return !SvOK(b);
    }
}

TXC(eq) {
    TX_st_sa = boolSV(  tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

TXC(ne) {
    TX_st_sa = boolSV( !tx_sv_eq(aTHX_ TX_st_sa, TX_st_sb) );

    TX_st->pc++;
}

TXC(lt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) < SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(le) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) <= SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(gt) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) > SvNVx(TX_st_sa) );
    TX_st->pc++;
}
TXC(ge) {
    TX_st_sa = boolSV( SvNVx(TX_st_sb) >= SvNVx(TX_st_sa) );
    TX_st->pc++;
}

TXC(macrocall) {
    U32 const addr = (U32)SvUVX(TX_st_sa);
    AV* cframe;
    dSP;
    dMARK;
    I32 i;
    SV* tmp;

    ENTER;
    SAVETMPS;

    /* push a new frame */
    cframe = tx_push_frame(aTHX_ TX_st);

    tmp                             = *av_fetch(cframe, TXframe_OUTPUT, TRUE);
    AvARRAY(cframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                   = tmp;
    sv_setpvs(tmp, "");

    /* macroname will be set by macro_begin */
    sv_setuv(*av_fetch(cframe, TXframe_RETADDR, TRUE), TX_st->pc + 1);

    if(SP != MARK) { /* has arguments */
        dORIGMARK;
        MARK++;
        i = 0; /* must start zero */
        while(MARK <= SP) {
            sv_setsv(TX_lvar(i), *MARK);
            MARK++;
            i++;
        }
        SP = ORIGMARK;
        PUTBACK;
    }

    TX_st->pc = addr;
}

TXC_w_key(macro_begin) {
    AV* const cframe  = TX_current_frame();

    sv_setsv(*av_fetch(cframe, TXframe_NAME, TRUE), TX_op_arg);

    TX_st->pc++;
}

TXC(macro_end) {
    AV* const oldframe  = TX_current_frame();
    AV* const cframe    = (AV*)AvARRAY(TX_st->frame)[--TX_st->current_frame];
    SV* const retaddr = AvARRAY(oldframe)[TXframe_RETADDR];
    SV* tmp;

    TX_st->pad = AvARRAY(cframe) + TXframe_START_LVAR; /* switch the pad */

    sv_setsv(TX_st->targ, tx_escaped_string(aTHX_ TX_st->output)); 
    TX_st_sa = TX_st->targ; /* retval */

    tmp                               = AvARRAY(oldframe)[TXframe_OUTPUT];
    AvARRAY(oldframe)[TXframe_OUTPUT] = TX_st->output;
    TX_st->output                     = tmp;

    TX_st->pc = SvUVX(retaddr);

    FREETMPS;
    LEAVE;
}

TXC_w_key(macro) {
    SV* const name = TX_op_arg;
    HE* he;
    if(TX_st->macro && (he = hv_fetch_ent(TX_st->macro, name, FALSE, 0U))) {
        TX_st_sa = hv_iterval(TX_st->macro, he);
    }

    if(!SvOK(TX_st_sa)) {
        croak("Macro %s is not defined", tx_neat(aTHX_ name));
    }

    TX_st->pc++;
}

TXC_w_key(function) {
    SV* const name = TX_op_arg;
    HE* he;

    if(TX_st->function && (he = hv_fetch_ent(TX_st->function, name, FALSE, 0U))) {
        TX_st_sa = hv_iterval(TX_st->function, he);
    }
    else {
        croak("Function %s is not registered", tx_neat(aTHX_ name));
    }

    TX_st->pc++;
}


TXC(funcall) {
    /* PUSHMARK & PUSH must be done */
    TX_st_sa = tx_call(aTHX_ TX_st, TX_st_sa, 0, "calling");

    TX_st->pc++;
}

TXC_goto(goto) {
    TX_st->pc = SvUVX(TX_op_arg);
}

TXC_w_sv(depend); /* indicate files for templates to depend on */

TXC(end) {
    TX_st->pc = TX_st->code_len;
}

XS(XS_Text__Xslate__error); /* -Wmissing-prototypes */
XS(XS_Text__Xslate__error) {
    dVAR; dXSARGS;
    dMY_CXT;
    tx_state_t* const st = (tx_state_t*)XSANY.any_ptr;
    AV* const cframe     = TX_current_framex(st);
    SV* const name       = AvARRAY(cframe)[TXframe_NAME];

    PERL_UNUSED_ARG(items);

    /* avoid recursion; they are retrieved at the end of the scope, anyway */
    PL_diehook  = NULL;
    PL_warnhook = NULL;

    MY_CXT.depth = 0;

    assert(st);

    /* unroll the stack frame */
    /* to fix TXframe_OUTPUT */
    while(st->current_frame > 0) {
        AV* const frame = (AV*)AvARRAY(st->frame)[st->current_frame];
        SV* tmp;
        st->current_frame--;

        /* swap st->output and TXframe_OUTPUT */
        tmp                            = AvARRAY(frame)[TXframe_OUTPUT];
        AvARRAY(frame)[TXframe_OUTPUT] = st->output;
        st->output                     = tmp;
    }

    croak("Xslate(%s:%d &%"SVf"[%d]): %"SVf,
        tx_file(aTHX_ st), tx_line(aTHX_ st),
        name, (int)st->pc, ST(0));
    XSRETURN_EMPTY; /* not reached */
}

static void
tx_execute(pTHX_ tx_state_t* const base, SV* const output, HV* const hv) {
    dMY_CXT;
    Size_t const code_len = base->code_len;
    tx_state_t st;
    SV* eh;

    StructCopy(base, &st, tx_state_t);

    st.output = output;
    st.vars   = hv;

    assert(st.tmpl != NULL);

    /* local $SIG{__WARN__} = \&error_handler */
    /* local $SIG{__DIE__} = \&error_handler */

    SAVESPTR(PL_warnhook);
    SAVESPTR(PL_diehook);
    eh = PL_warnhook = PL_diehook = AvARRAY(st.tmpl)[TXo_ERROR_HANDLER];

    if(SvROK(eh) && SvTYPE(SvRV(eh)) == SVt_PVCV
        && CvXSUB((CV*)SvRV(eh)) == XS_Text__Xslate__error) {
        CvXSUBANY((CV*)SvRV(eh)).any_ptr = &st;
    }

    if(++MY_CXT.depth > 100) {
        croak("Execution is too deep (> 100)");
    }

    while(st.pc < code_len) {
#ifdef DEBUGGING
        Size_t const old_pc = st.pc;
#endif
        CALL_FPTR(st.code[st.pc].exec_code)(aTHX_ &st);
#ifdef DEBUGGING
        if(UNLIKELY(old_pc == st.pc)) {
            croak("panic: pogram counter has not been changed on [%d]", (int)st.pc);
        }
#endif
    }

    base->hint_size = SvCUR(st.output);

    MY_CXT.depth--;
}


static MAGIC*
mgx_find(pTHX_ SV* const sv, const MGVTBL* const vtbl){
    MAGIC* mg;

    assert(sv   != NULL);
    assert(vtbl != NULL);

    for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
        if(mg->mg_virtual == vtbl){
            assert(mg->mg_type == PERL_MAGIC_ext);
            return mg;
        }
    }

    croak("Xslate: Invalid xslate object was passed");
    return NULL; /* not reached */
}

static int
tx_mg_free(pTHX_ SV* const sv, MAGIC* const mg){
    tx_state_t* const st  = (tx_state_t*)mg->mg_ptr;
    tx_code_t* const code = st->code;
    I32 const len         = st->code_len;
    I32 i;

    for(i = 0; i < len; i++) {
        SvREFCNT_dec(code[i].arg);
    }

    Safefree(code);
    Safefree(st->lines);

    SvREFCNT_dec(st->function);
    SvREFCNT_dec(st->macro);
    SvREFCNT_dec(st->frame);
    SvREFCNT_dec(st->targ);
    SvREFCNT_dec(st->self);

    PERL_UNUSED_ARG(sv);

    return 0;
}

#ifdef USE_ITHREADS
static SV*
tx_sv_dup_inc(pTHX_ const SV* const sv, CLONE_PARAMS* const param) {
    SV* const newsv = sv_dup(sv, param);
    SvREFCNT_inc_simple_void(newsv);
    return newsv;
}
#endif

static int
tx_mg_dup(pTHX_ MAGIC* const mg, CLONE_PARAMS* const param){
#ifdef USE_ITHREADS /* single threaded perl has no "xxx_dup()" APIs */
    tx_state_t* const st              = (tx_state_t*)mg->mg_ptr;
    const U16* const proto_lines      = st->lines;
    const tx_code_t* const proto_code = st->code;
    I32 const len                     = st->code_len;
    I32 i;

    Newx(st->code, len, tx_code_t);

    for(i = 0; i < len; i++) {
        st->code[i].exec_code = proto_code[i].exec_code;
        st->code[i].arg       = tx_sv_dup_inc(aTHX_ proto_code[i].arg, param);
    }

    Newx(st->lines, len, U16);
    Copy(proto_lines, st->lines, len, U16);

    st->function = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->function, param);
    st->macro    = (HV*)tx_sv_dup_inc(aTHX_ (SV*)st->macro,    param);
    st->frame    = (AV*)tx_sv_dup_inc(aTHX_ (SV*)st->frame,    param);
    st->targ     =      tx_sv_dup_inc(aTHX_ st->targ, param);
    st->self     =      tx_sv_dup_inc(aTHX_ st->self, param);
#else
    PERL_UNUSED_VAR(mg);
    PERL_UNUSED_VAR(param);
#endif
    return 0;
}


static MGVTBL xslate_vtbl = { /* for identity */
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    tx_mg_free, /* free */
    NULL, /* copy */
    tx_mg_dup, /* dup */
    NULL,  /* local */
};


static void
tx_invoke_load_file(pTHX_ SV* const self, SV* const name) {
    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(self);
    PUSHs(name);
    PUTBACK;

    call_method("load_file", G_EVAL | G_VOID);

    FREETMPS;
    LEAVE;
}

static bool
tx_all_deps_are_fresh(pTHX_ AV* const tmpl, Time_t const cache_mtime) {
    I32 const len = AvFILLp(tmpl) + 1;
    I32 i;
    Stat_t f;

    for(i = TXo_FULLPATH; i < len; i++) {
        SV* const deppath = AvARRAY(tmpl)[i];

        if(!SvOK(deppath)) {
            continue;
        }

        //PerlIO_stdoutf("check deps: %"SVf" ... ", path); // */
        if(PerlLIO_stat(SvPV_nolen_const(deppath), &f) < 0
               || f.st_mtime > cache_mtime) {
            SV* const mainpath = AvARRAY(tmpl)[TXo_FULLPATH];
            /* compiled files are no longer fresh, so it must be discarded */

            if(i != TXo_FULLPATH && SvOK(mainpath)) {
                PerlLIO_unlink(Perl_form(aTHX_ "%"SVf"c", mainpath));
            }
            PerlLIO_unlink(Perl_form(aTHX_ "%"SVf"c", deppath));

            //PerlIO_stdoutf("%"SVf": too old (%d > %d)\n", deppath, (int)f.st_mtime, (int)cache_mtime); // */
            return FALSE;
        }
        else {
            //PerlIO_stdoutf("%"SVf": fresh enough\n", deppath); // */
        }
    }
    return TRUE;
}

static tx_state_t*
tx_load_template(pTHX_ SV* const self, SV* const name) {
    HV* hv;
    const char* why = NULL;
    HE* he;
    SV** svp;
    SV* sv;
    HV* ttable;
    AV* tmpl;
    MAGIC* mg;
    SV* cache_mtime;
    int retried = 0;

    //PerlIO_stdoutf("load_template(%"SVf")\n", name);

    if(!(SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV)) {
        croak("Invalid xslate object");
    }

    hv = (HV*)SvRV(self);

    retry:
    if(retried > 1) {
        why = "retried reloading, but failed";
        goto err;
    }

    /* validation by modified time (mtime) */

    /* my $ttable = $self->{template} */
    svp = hv_fetchs(hv, "template", FALSE);
    if(!svp) {
        why = "template table is not found";
        goto err;
    }

    sv = *svp;
    if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)) {
        why = "template table is not a HASH reference";
        goto err;
    }

    ttable = (HV*)SvRV(sv);

    /* $tmpl = $ttable->{$name} */
    he = hv_fetch_ent(ttable, name, FALSE, 0U);
    if(!he) {
        tx_invoke_load_file(aTHX_ self, name);
        if(sv_true(ERRSV)){
            why = SvPVx_nolen_const(ERRSV);
            goto err;
        }

        retried++;
        goto retry;
    }

    sv = hv_iterval(ttable, he);
    if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)) {
        why = "template entry is invalid";
        goto err;
    }

    tmpl = (AV*)SvRV(sv);
    mg   = mgx_find(aTHX_ (SV*)tmpl, &xslate_vtbl);

    if(AvFILLp(tmpl) < (TXo_least_size-1)) {
        why = form("template entry is broken (size:%d < %d)", AvFILLp(tmpl)+1, TXo_least_size);
        goto err;
    }

    /* check mtime */

    cache_mtime = AvARRAY(tmpl)[TXo_MTIME];

    if(!SvIOK(cache_mtime)) { /* non-checking mode (i.e. release mode) */
        return (tx_state_t*)mg->mg_ptr;
    }

    //PerlIO_stdoutf("###%d %d >= %d\n", (int)retried, (int)SvIVX(cache_mtime), (int)f.st_mtime);

    if(retried > 0 /* if already retried, it should be valid */
            || tx_all_deps_are_fresh(aTHX_ tmpl, SvIVX(cache_mtime))) {
        return (tx_state_t*)mg->mg_ptr;
    }
    else {
        tx_invoke_load_file(aTHX_ self, name);
        retried++;
        goto retry;
    }

    err:
    croak("Xslate: Cannot load template %s: %s", tx_neat(aTHX_ name), why);
}


MODULE = Text::Xslate    PACKAGE = Text::Xslate

PROTOTYPES: DISABLE

BOOT:
{
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADDMULTI);
    MY_CXT_INIT;
    MY_CXT.depth = 0;
    MY_CXT.escaped_string_stash = gv_stashpvs(TX_ESC_CLASS, GV_ADDMULTI);
    tx_init_ops(aTHX_ ops);
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
    MY_CXT_CLONE;
    MY_CXT.depth = 0;
    MY_CXT.escaped_string_stash = gv_stashpvs(TX_ESC_CLASS, GV_ADDMULTI);
    PERL_UNUSED_VAR(items);
}

#endif

#define undef &PL_sv_undef

void
_initialize(HV* self, AV* proto, SV* name = undef, SV* fullpath = undef, SV* mtime = undef)
CODE:
{
    MAGIC* mg;
    HV* const ops = get_hv("Text::Xslate::OPS", GV_ADD);
    I32 const len = av_len(proto) + 1;
    I32 i;
    U16 l = 0;
    tx_state_t st;
    AV* tmpl;
    SV* tobj;
    SV** svp;
    AV* mainframe;

    Zero(&st, 1, tx_state_t);

    svp = hv_fetchs(self, "template", FALSE);
    if(!(svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV)) {
        croak("The xslate object has no template table");
    }

    if(!SvOK(name)) { /* for strings */
        name  = newSVpvs_flags("<input>", SVs_TEMP);
        mtime = sv_2mortal(newSViv( time(NULL) ));
    }

    tobj = hv_iterval((HV*)SvRV(*svp),
         hv_fetch_ent((HV*)SvRV(*svp), name, TRUE, 0U)
    );

    svp = hv_fetchs(self, "function", FALSE);
    if(svp && SvOK(*svp)) {
        if(SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV) {
            st.function = (HV*)SvRV(*svp);
            SvREFCNT_inc_simple_void_NN(st.function);
        }
        else {
            croak("Function table must be a HASH reference");
        }
    }

    tmpl = newAV();
    sv_setsv(tobj, sv_2mortal(newRV_noinc((SV*)tmpl)));
    av_extend(tmpl, TXo_least_size - 1);

    /* tmpl = [name, fullpath, mtime of the file, error_handler] */

    svp = hv_fetchs(self, "error_handler", FALSE);
    if(svp && SvOK(*svp)) {
        sv_setsv(*av_fetch(tmpl, TXo_ERROR_HANDLER, TRUE), *svp);
    }
    else {
        CV* const eh = newXS(NULL, XS_Text__Xslate__error, __FILE__);
        sv_setsv(*av_fetch(tmpl, TXo_ERROR_HANDLER, TRUE), sv_2mortal(newRV_noinc((SV*)eh)));
    }

    sv_setsv(*av_fetch(tmpl, TXo_NAME,     TRUE), name);
    sv_setsv(*av_fetch(tmpl, TXo_MTIME,    TRUE), mtime );
    sv_setsv(*av_fetch(tmpl, TXo_FULLPATH, TRUE), fullpath);

    st.tmpl = tmpl;
    st.self = newRV_inc((SV*)self);
    sv_rvweaken(st.self);

    st.hint_size = 64;

    st.sa       = &PL_sv_undef;
    st.sb       = &PL_sv_undef;
    st.targ     = newSV(0);

    /* stack frame */
    st.frame         = newAV();
    st.current_frame = -1;

    mainframe = tx_push_frame(aTHX_ &st);
    av_store(mainframe, TXframe_NAME,    newSVpvs_share("main"));
    av_store(mainframe, TXframe_RETADDR, newSVuv(len));

    Newxz(st.lines, len, U16);

    Newxz(st.code, len, tx_code_t);

    st.code_len = len;

    mg = sv_magicext((SV*)tmpl, NULL, PERL_MAGIC_ext, &xslate_vtbl, (char*)&st, sizeof(st));
    mg->mg_flags |= MGf_DUP;

    for(i = 0; i < len; i++) {
        SV* const pair = *av_fetch(proto, i, TRUE);
        if(SvROK(pair) && SvTYPE(SvRV(pair)) == SVt_PVAV) {
            AV* const av     = (AV*)SvRV(pair);
            SV* const opname = *av_fetch(av, 0, TRUE);
            SV** const arg   =  av_fetch(av, 1, FALSE);
            SV** const line  =  av_fetch(av, 2, FALSE);
            HE* const he     = hv_fetch_ent(ops, opname, FALSE, 0U);
            IV  opnum;

            if(!he){
                croak("Oops: Unknown opcode '%"SVf"' on [%d]", opname, (int)i);
            }

            opnum                = SvIVx(hv_iterval(ops, he));
            st.code[i].exec_code = tx_opcode[ opnum ];
            if(tx_oparg[opnum] & TXARGf_SV) {
                if(!arg) {
                    croak("Oops: Opcode %"SVf" must have an argument on [%d]", opname, (int)i);
                }

                if(tx_oparg[opnum] & TXARGf_KEY) {
                    STRLEN len;
                    const char* const pv = SvPV_const(*arg, len);
                    st.code[i].arg = newSVpvn_share(pv, len, 0U);
                }
                else if(tx_oparg[opnum] & TXARGf_INT) {
                    st.code[i].arg = newSViv(SvIV(*arg));

                    if(tx_oparg[opnum] & TXARGf_GOTO) {
                        /* calculate relational addresses to absolute addresses */
                        UV const abs_addr = (UV)(i + SvIVX(st.code[i].arg));
                        if(abs_addr > (UV)len) {
                            croak("Oops: goto address %"IVdf" is out of range (must be 0 <= addr <= %"IVdf")",
                                SvIVX(st.code[i].arg), (IV)len);
                        }
                        sv_setuv(st.code[i].arg, abs_addr);
                    }
                    SvREADONLY_on(st.code[i].arg);
                }
                else { /* normal sv */
                    st.code[i].arg = newSVsv(*arg);
                }
            }
            else {
                if(arg && SvOK(*arg)) {
                    croak("Oops: Opcode %"SVf" has an extra argument on [%d]", opname, (int)i);
                }
                st.code[i].arg = NULL;
            }

            /* setup line number */
            if(line && SvOK(*line)) {
                l = (U16)SvIV(*line);
            }
            st.lines[i] = l;


            /* special cases */
            if(opnum == TXOP_macro_begin) {
                if(!st.macro) {
                    st.macro = newHV();
                    ((tx_state_t*)mg->mg_ptr)->macro = st.macro;
                }
                (void)hv_store_ent(st.macro, st.code[i].arg, newSViv(i), 0U);
            }
            else if(opnum == TXOP_depend) {
                /* add a dependent file to the tmpl object */
                av_push(tmpl, SvREFCNT_inc_simple_NN(st.code[i].arg));
            }
        }
        else {
            croak("Oops: Broken code found on [%d]", (int)i);
        }
    } /* end for each code */
}

SV*
render(SV* self, ...)
CODE:
{
    SV* name;
    SV* vars_ref;
    HV* vars;
    tx_state_t* st;

    if(items < 2) {
        croak_xs_usage(cv,  "self, name, vars");
    }

    if(items == 2) {
        name     = newSVpvs_flags("<input>", SVs_TEMP);
        vars_ref = ST(1);
    }
    else {
        name     = ST(1);
        vars_ref = ST(2);
    }

    if(!(SvROK(vars_ref) && SvTYPE(SvRV(vars_ref)) == SVt_PVHV)) {
        croak("Xslate: Template variables must be a HASH reference");
    }
    vars = (HV*)SvRV(vars_ref);

    st = tx_load_template(aTHX_ self, name);

    RETVAL = sv_newmortal();
    sv_grow(RETVAL, st->hint_size);
    SvPOK_on(RETVAL);

    tx_execute(aTHX_ st, RETVAL, vars);

    ST(0) = RETVAL;
    XSRETURN(1);
}

void
escaped_string(SV* str)
CODE:
{
    ST(0) = tx_escaped_string(aTHX_ str);
    XSRETURN(1);
}

MODULE = Text::Xslate    PACKAGE = Text::Xslate::EscapedString

FALLBACK: TRUE

void
new(SV* klass, SV* str)
CODE:
{
    if(SvROK(klass)) {
        croak("Cannot call %s->new as an instance method", TX_ESC_CLASS);
    }
    if(strNE(SvPV_nolen_const(klass), TX_ESC_CLASS)) {
        croak("You cannot use a subclass from %s as a escaped string", TX_ESC_CLASS);
    }
    ST(0) = tx_escaped_string(aTHX_ str);
    XSRETURN(1);
}

void
as_string(SV* self, ...)
OVERLOAD: \"\"
CODE:
{
    if(!( SvROK(self) && SvOK(SvRV(self))) ) {
        croak("Cannot call %s->as_string as a class method", TX_ESC_CLASS);
    }
    ST(0) = SvRV(self);
    XSRETURN(1);
}

