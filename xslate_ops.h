/* This file is automatically generated by tool/opcode.pl.
 * ANY CHANGES WILL BE LOST!
 */

/* forward decl for Xslate opcodes */
TXC(noop);
TXC(move_to_sb);
TXC(move_from_sb);
TXC_w_var(save_to_lvar);
TXC_w_var(load_lvar);
TXC_w_var(load_lvar_to_sb);
TXC_w_key(localize_s);
TXC(push);
TXC(pushmark);
TXC(nil);
TXC_w_sv(literal);
TXC_w_int(literal_i);
TXC_w_key(fetch_s); /* fetch a field from the top */
TXC(fetch_field); /* fetch a field from a variable (bin operator) */
TXC_w_key(fetch_field_s); /* fetch a field from a variable (for literal) */
TXC(print);
TXC(print_raw);
TXC_w_sv(print_raw_s);
TXC(include);
TXC_w_var(for_start);
TXC_goto(for_iter);
TXC(add);
TXC(sub);
TXC(mul);
TXC(div);
TXC(mod);
TXC_w_sv(concat);
TXC_goto(and);
TXC_goto(dand);
TXC_goto(or);
TXC_goto(dor);
TXC(not);
TXC(minus); /* unary minus */
TXC(max_index);
TXC(builtin_mark_raw);
TXC(builtin_unmark_raw);
TXC(builtin_html_escape);
TXC(match);
TXC(eq);
TXC(ne);
TXC(lt);
TXC(le);
TXC(gt);
TXC(ge);
TXC(ncmp);
TXC(scmp);
TXC_w_key(symbol); /* find a symbol (function, macro, constant) */
TXC_w_int(macro_end);
TXC(funcall); /* call a function or a macro */
TXC_w_key(methodcall_s);
TXC(make_array);
TXC(make_hash);
TXC(enter);
TXC(leave);
TXC_goto(goto);
TXC_w_sv(depend); /* tell the vm to dependent template files */
TXC_w_key(macro_begin);
TXC_w_int(macro_nargs);
TXC_w_int(macro_outer);
TXC(set_opinfo);
TXC(end);

enum tx_opcode_t {
    TXOP_noop, /* 0 */
    TXOP_move_to_sb, /* 1 */
    TXOP_move_from_sb, /* 2 */
    TXOP_save_to_lvar, /* 3 */
    TXOP_load_lvar, /* 4 */
    TXOP_load_lvar_to_sb, /* 5 */
    TXOP_localize_s, /* 6 */
    TXOP_push, /* 7 */
    TXOP_pushmark, /* 8 */
    TXOP_nil, /* 9 */
    TXOP_literal, /* 10 */
    TXOP_literal_i, /* 11 */
    TXOP_fetch_s, /* 12 */
    TXOP_fetch_field, /* 13 */
    TXOP_fetch_field_s, /* 14 */
    TXOP_print, /* 15 */
    TXOP_print_raw, /* 16 */
    TXOP_print_raw_s, /* 17 */
    TXOP_include, /* 18 */
    TXOP_for_start, /* 19 */
    TXOP_for_iter, /* 20 */
    TXOP_add, /* 21 */
    TXOP_sub, /* 22 */
    TXOP_mul, /* 23 */
    TXOP_div, /* 24 */
    TXOP_mod, /* 25 */
    TXOP_concat, /* 26 */
    TXOP_and, /* 27 */
    TXOP_dand, /* 28 */
    TXOP_or, /* 29 */
    TXOP_dor, /* 30 */
    TXOP_not, /* 31 */
    TXOP_minus, /* 32 */
    TXOP_max_index, /* 33 */
    TXOP_builtin_mark_raw, /* 34 */
    TXOP_builtin_unmark_raw, /* 35 */
    TXOP_builtin_html_escape, /* 36 */
    TXOP_match, /* 37 */
    TXOP_eq, /* 38 */
    TXOP_ne, /* 39 */
    TXOP_lt, /* 40 */
    TXOP_le, /* 41 */
    TXOP_gt, /* 42 */
    TXOP_ge, /* 43 */
    TXOP_ncmp, /* 44 */
    TXOP_scmp, /* 45 */
    TXOP_symbol, /* 46 */
    TXOP_macro_end, /* 47 */
    TXOP_funcall, /* 48 */
    TXOP_methodcall_s, /* 49 */
    TXOP_make_array, /* 50 */
    TXOP_make_hash, /* 51 */
    TXOP_enter, /* 52 */
    TXOP_leave, /* 53 */
    TXOP_goto, /* 54 */
    TXOP_depend, /* 55 */
    TXOP_macro_begin, /* 56 */
    TXOP_macro_nargs, /* 57 */
    TXOP_macro_outer, /* 58 */
    TXOP_set_opinfo, /* 59 */
    TXOP_end, /* 60 */
    TXOP_last
}; /* enum tx_opcode_t */

static const U8 tx_oparg[] = {
    0U, /* noop */
    0U, /* move_to_sb */
    0U, /* move_from_sb */
    TXCODE_W_VAR, /* save_to_lvar */
    TXCODE_W_VAR, /* load_lvar */
    TXCODE_W_VAR, /* load_lvar_to_sb */
    TXCODE_W_KEY, /* localize_s */
    0U, /* push */
    0U, /* pushmark */
    0U, /* nil */
    TXCODE_W_SV, /* literal */
    TXCODE_W_INT, /* literal_i */
    TXCODE_W_KEY, /* fetch_s */
    0U, /* fetch_field */
    TXCODE_W_KEY, /* fetch_field_s */
    0U, /* print */
    0U, /* print_raw */
    TXCODE_W_SV, /* print_raw_s */
    0U, /* include */
    TXCODE_W_VAR, /* for_start */
    TXCODE_GOTO, /* for_iter */
    0U, /* add */
    0U, /* sub */
    0U, /* mul */
    0U, /* div */
    0U, /* mod */
    TXCODE_W_SV, /* concat */
    TXCODE_GOTO, /* and */
    TXCODE_GOTO, /* dand */
    TXCODE_GOTO, /* or */
    TXCODE_GOTO, /* dor */
    0U, /* not */
    0U, /* minus */
    0U, /* max_index */
    0U, /* builtin_mark_raw */
    0U, /* builtin_unmark_raw */
    0U, /* builtin_html_escape */
    0U, /* match */
    0U, /* eq */
    0U, /* ne */
    0U, /* lt */
    0U, /* le */
    0U, /* gt */
    0U, /* ge */
    0U, /* ncmp */
    0U, /* scmp */
    TXCODE_W_KEY, /* symbol */
    TXCODE_W_INT, /* macro_end */
    0U, /* funcall */
    TXCODE_W_KEY, /* methodcall_s */
    0U, /* make_array */
    0U, /* make_hash */
    0U, /* enter */
    0U, /* leave */
    TXCODE_GOTO, /* goto */
    TXCODE_W_SV, /* depend */
    TXCODE_W_KEY, /* macro_begin */
    TXCODE_W_INT, /* macro_nargs */
    TXCODE_W_INT, /* macro_outer */
    0U, /* set_opinfo */
    0U, /* end */
}; /* tx_oparg[] */

static void
tx_init_ops(pTHX_ HV* const ops) {
    (void)hv_stores(ops, STRINGIFY(noop), newSViv(TXOP_noop));
    (void)hv_stores(ops, STRINGIFY(move_to_sb), newSViv(TXOP_move_to_sb));
    (void)hv_stores(ops, STRINGIFY(move_from_sb), newSViv(TXOP_move_from_sb));
    (void)hv_stores(ops, STRINGIFY(save_to_lvar), newSViv(TXOP_save_to_lvar));
    (void)hv_stores(ops, STRINGIFY(load_lvar), newSViv(TXOP_load_lvar));
    (void)hv_stores(ops, STRINGIFY(load_lvar_to_sb), newSViv(TXOP_load_lvar_to_sb));
    (void)hv_stores(ops, STRINGIFY(localize_s), newSViv(TXOP_localize_s));
    (void)hv_stores(ops, STRINGIFY(push), newSViv(TXOP_push));
    (void)hv_stores(ops, STRINGIFY(pushmark), newSViv(TXOP_pushmark));
    (void)hv_stores(ops, STRINGIFY(nil), newSViv(TXOP_nil));
    (void)hv_stores(ops, STRINGIFY(literal), newSViv(TXOP_literal));
    (void)hv_stores(ops, STRINGIFY(literal_i), newSViv(TXOP_literal_i));
    (void)hv_stores(ops, STRINGIFY(fetch_s), newSViv(TXOP_fetch_s));
    (void)hv_stores(ops, STRINGIFY(fetch_field), newSViv(TXOP_fetch_field));
    (void)hv_stores(ops, STRINGIFY(fetch_field_s), newSViv(TXOP_fetch_field_s));
    (void)hv_stores(ops, STRINGIFY(print), newSViv(TXOP_print));
    (void)hv_stores(ops, STRINGIFY(print_raw), newSViv(TXOP_print_raw));
    (void)hv_stores(ops, STRINGIFY(print_raw_s), newSViv(TXOP_print_raw_s));
    (void)hv_stores(ops, STRINGIFY(include), newSViv(TXOP_include));
    (void)hv_stores(ops, STRINGIFY(for_start), newSViv(TXOP_for_start));
    (void)hv_stores(ops, STRINGIFY(for_iter), newSViv(TXOP_for_iter));
    (void)hv_stores(ops, STRINGIFY(add), newSViv(TXOP_add));
    (void)hv_stores(ops, STRINGIFY(sub), newSViv(TXOP_sub));
    (void)hv_stores(ops, STRINGIFY(mul), newSViv(TXOP_mul));
    (void)hv_stores(ops, STRINGIFY(div), newSViv(TXOP_div));
    (void)hv_stores(ops, STRINGIFY(mod), newSViv(TXOP_mod));
    (void)hv_stores(ops, STRINGIFY(concat), newSViv(TXOP_concat));
    (void)hv_stores(ops, STRINGIFY(and), newSViv(TXOP_and));
    (void)hv_stores(ops, STRINGIFY(dand), newSViv(TXOP_dand));
    (void)hv_stores(ops, STRINGIFY(or), newSViv(TXOP_or));
    (void)hv_stores(ops, STRINGIFY(dor), newSViv(TXOP_dor));
    (void)hv_stores(ops, STRINGIFY(not), newSViv(TXOP_not));
    (void)hv_stores(ops, STRINGIFY(minus), newSViv(TXOP_minus));
    (void)hv_stores(ops, STRINGIFY(max_index), newSViv(TXOP_max_index));
    (void)hv_stores(ops, STRINGIFY(builtin_mark_raw), newSViv(TXOP_builtin_mark_raw));
    (void)hv_stores(ops, STRINGIFY(builtin_unmark_raw), newSViv(TXOP_builtin_unmark_raw));
    (void)hv_stores(ops, STRINGIFY(builtin_html_escape), newSViv(TXOP_builtin_html_escape));
    (void)hv_stores(ops, STRINGIFY(match), newSViv(TXOP_match));
    (void)hv_stores(ops, STRINGIFY(eq), newSViv(TXOP_eq));
    (void)hv_stores(ops, STRINGIFY(ne), newSViv(TXOP_ne));
    (void)hv_stores(ops, STRINGIFY(lt), newSViv(TXOP_lt));
    (void)hv_stores(ops, STRINGIFY(le), newSViv(TXOP_le));
    (void)hv_stores(ops, STRINGIFY(gt), newSViv(TXOP_gt));
    (void)hv_stores(ops, STRINGIFY(ge), newSViv(TXOP_ge));
    (void)hv_stores(ops, STRINGIFY(ncmp), newSViv(TXOP_ncmp));
    (void)hv_stores(ops, STRINGIFY(scmp), newSViv(TXOP_scmp));
    (void)hv_stores(ops, STRINGIFY(symbol), newSViv(TXOP_symbol));
    (void)hv_stores(ops, STRINGIFY(macro_end), newSViv(TXOP_macro_end));
    (void)hv_stores(ops, STRINGIFY(funcall), newSViv(TXOP_funcall));
    (void)hv_stores(ops, STRINGIFY(methodcall_s), newSViv(TXOP_methodcall_s));
    (void)hv_stores(ops, STRINGIFY(make_array), newSViv(TXOP_make_array));
    (void)hv_stores(ops, STRINGIFY(make_hash), newSViv(TXOP_make_hash));
    (void)hv_stores(ops, STRINGIFY(enter), newSViv(TXOP_enter));
    (void)hv_stores(ops, STRINGIFY(leave), newSViv(TXOP_leave));
    (void)hv_stores(ops, STRINGIFY(goto), newSViv(TXOP_goto));
    (void)hv_stores(ops, STRINGIFY(depend), newSViv(TXOP_depend));
    (void)hv_stores(ops, STRINGIFY(macro_begin), newSViv(TXOP_macro_begin));
    (void)hv_stores(ops, STRINGIFY(macro_nargs), newSViv(TXOP_macro_nargs));
    (void)hv_stores(ops, STRINGIFY(macro_outer), newSViv(TXOP_macro_outer));
    (void)hv_stores(ops, STRINGIFY(set_opinfo), newSViv(TXOP_set_opinfo));
    (void)hv_stores(ops, STRINGIFY(end), newSViv(TXOP_end));
} /* tx_register_ops() */

#ifndef TX_DIRECT_THREADED_CODE
#define dTX_optable dNOOP
static const tx_exec_t tx_optable[] = {
    TXCODE_noop,
    TXCODE_move_to_sb,
    TXCODE_move_from_sb,
    TXCODE_save_to_lvar,
    TXCODE_load_lvar,
    TXCODE_load_lvar_to_sb,
    TXCODE_localize_s,
    TXCODE_push,
    TXCODE_pushmark,
    TXCODE_nil,
    TXCODE_literal,
    TXCODE_literal_i,
    TXCODE_fetch_s,
    TXCODE_fetch_field,
    TXCODE_fetch_field_s,
    TXCODE_print,
    TXCODE_print_raw,
    TXCODE_print_raw_s,
    TXCODE_include,
    TXCODE_for_start,
    TXCODE_for_iter,
    TXCODE_add,
    TXCODE_sub,
    TXCODE_mul,
    TXCODE_div,
    TXCODE_mod,
    TXCODE_concat,
    TXCODE_and,
    TXCODE_dand,
    TXCODE_or,
    TXCODE_dor,
    TXCODE_not,
    TXCODE_minus,
    TXCODE_max_index,
    TXCODE_builtin_mark_raw,
    TXCODE_builtin_unmark_raw,
    TXCODE_builtin_html_escape,
    TXCODE_match,
    TXCODE_eq,
    TXCODE_ne,
    TXCODE_lt,
    TXCODE_le,
    TXCODE_gt,
    TXCODE_ge,
    TXCODE_ncmp,
    TXCODE_scmp,
    TXCODE_symbol,
    TXCODE_macro_end,
    TXCODE_funcall,
    TXCODE_methodcall_s,
    TXCODE_make_array,
    TXCODE_make_hash,
    TXCODE_enter,
    TXCODE_leave,
    TXCODE_goto,
    TXCODE_depend,
    TXCODE_macro_begin,
    TXCODE_macro_nargs,
    TXCODE_macro_outer,
    TXCODE_set_opinfo,
    TXCODE_end,
    NULL
}; /* tx_optable[] */

#else /* TX_DIRECT_THREADED_CODE */
#define dTX_optable void const* const* const tx_optable \
                    = tx_runops(aTHX_ NULL)
#define LABEL(x)     CAT2(TX_DTC_, x)
#define LABEL_PTR(x) &&LABEL(x)
static void const* const*
tx_runops(pTHX_ tx_state_t* const st) {
    static const void* const ops_address_table[] = {
        LABEL_PTR(noop),
        LABEL_PTR(move_to_sb),
        LABEL_PTR(move_from_sb),
        LABEL_PTR(save_to_lvar),
        LABEL_PTR(load_lvar),
        LABEL_PTR(load_lvar_to_sb),
        LABEL_PTR(localize_s),
        LABEL_PTR(push),
        LABEL_PTR(pushmark),
        LABEL_PTR(nil),
        LABEL_PTR(literal),
        LABEL_PTR(literal_i),
        LABEL_PTR(fetch_s),
        LABEL_PTR(fetch_field),
        LABEL_PTR(fetch_field_s),
        LABEL_PTR(print),
        LABEL_PTR(print_raw),
        LABEL_PTR(print_raw_s),
        LABEL_PTR(include),
        LABEL_PTR(for_start),
        LABEL_PTR(for_iter),
        LABEL_PTR(add),
        LABEL_PTR(sub),
        LABEL_PTR(mul),
        LABEL_PTR(div),
        LABEL_PTR(mod),
        LABEL_PTR(concat),
        LABEL_PTR(and),
        LABEL_PTR(dand),
        LABEL_PTR(or),
        LABEL_PTR(dor),
        LABEL_PTR(not),
        LABEL_PTR(minus),
        LABEL_PTR(max_index),
        LABEL_PTR(builtin_mark_raw),
        LABEL_PTR(builtin_unmark_raw),
        LABEL_PTR(builtin_html_escape),
        LABEL_PTR(match),
        LABEL_PTR(eq),
        LABEL_PTR(ne),
        LABEL_PTR(lt),
        LABEL_PTR(le),
        LABEL_PTR(gt),
        LABEL_PTR(ge),
        LABEL_PTR(ncmp),
        LABEL_PTR(scmp),
        LABEL_PTR(symbol),
        LABEL_PTR(macro_end),
        LABEL_PTR(funcall),
        LABEL_PTR(methodcall_s),
        LABEL_PTR(make_array),
        LABEL_PTR(make_hash),
        LABEL_PTR(enter),
        LABEL_PTR(leave),
        LABEL_PTR(goto),
        LABEL_PTR(depend),
        LABEL_PTR(macro_begin),
        LABEL_PTR(macro_nargs),
        LABEL_PTR(macro_outer),
        LABEL_PTR(set_opinfo),
        LABEL_PTR(end)
    }; /* end of ops_address_table */
    if(UNLIKELY(st == NULL)) {
        return ops_address_table;
    }

    goto *(st->pc->exec_code); /* start */

    /* dispatch */
    LABEL(noop                ): TXCODE_noop                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(move_to_sb          ): TXCODE_move_to_sb          (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(move_from_sb        ): TXCODE_move_from_sb        (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(save_to_lvar        ): TXCODE_save_to_lvar        (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(load_lvar           ): TXCODE_load_lvar           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(load_lvar_to_sb     ): TXCODE_load_lvar_to_sb     (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(localize_s          ): TXCODE_localize_s          (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(push                ): TXCODE_push                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(pushmark            ): TXCODE_pushmark            (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(nil                 ): TXCODE_nil                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(literal             ): TXCODE_literal             (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(literal_i           ): TXCODE_literal_i           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(fetch_s             ): TXCODE_fetch_s             (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(fetch_field         ): TXCODE_fetch_field         (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(fetch_field_s       ): TXCODE_fetch_field_s       (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(print               ): TXCODE_print               (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(print_raw           ): TXCODE_print_raw           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(print_raw_s         ): TXCODE_print_raw_s         (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(include             ): TXCODE_include             (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(for_start           ): TXCODE_for_start           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(for_iter            ): TXCODE_for_iter            (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(add                 ): TXCODE_add                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(sub                 ): TXCODE_sub                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(mul                 ): TXCODE_mul                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(div                 ): TXCODE_div                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(mod                 ): TXCODE_mod                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(concat              ): TXCODE_concat              (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(and                 ): TXCODE_and                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(dand                ): TXCODE_dand                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(or                  ): TXCODE_or                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(dor                 ): TXCODE_dor                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(not                 ): TXCODE_not                 (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(minus               ): TXCODE_minus               (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(max_index           ): TXCODE_max_index           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(builtin_mark_raw    ): TXCODE_builtin_mark_raw    (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(builtin_unmark_raw  ): TXCODE_builtin_unmark_raw  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(builtin_html_escape ): TXCODE_builtin_html_escape (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(match               ): TXCODE_match               (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(eq                  ): TXCODE_eq                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(ne                  ): TXCODE_ne                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(lt                  ): TXCODE_lt                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(le                  ): TXCODE_le                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(gt                  ): TXCODE_gt                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(ge                  ): TXCODE_ge                  (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(ncmp                ): TXCODE_ncmp                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(scmp                ): TXCODE_scmp                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(symbol              ): TXCODE_symbol              (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(macro_end           ): TXCODE_macro_end           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(funcall             ): TXCODE_funcall             (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(methodcall_s        ): TXCODE_methodcall_s        (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(make_array          ): TXCODE_make_array          (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(make_hash           ): TXCODE_make_hash           (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(enter               ): TXCODE_enter               (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(leave               ): TXCODE_leave               (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(goto                ): TXCODE_goto                (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(depend              ): TXCODE_depend              (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(macro_begin         ): TXCODE_macro_begin         (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(macro_nargs         ): TXCODE_macro_nargs         (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(macro_outer         ): TXCODE_macro_outer         (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(set_opinfo          ): TXCODE_set_opinfo          (aTHX_ st); goto *(st->pc->exec_code);
    LABEL(end): TXCODE_end(aTHX_ st);
    return NULL;
} /* end of tx_runops() */
#undef LABEL
#undef LABEL_PTR
#endif /* TX_DIRECT_THREADED_CODE */

