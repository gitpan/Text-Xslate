package Text::Xslate::Compiler;
use 5.010;
use Any::Moose;
use Any::Moose '::Util::TypeConstraints';

use Text::Xslate::Parser;
use Text::Xslate::Util qw(
    $DEBUG
    literal_to_value
    is_int
    p
);

use Scalar::Util ();

use constant _DUMP_ASM => scalar($DEBUG =~ /\b dump=asm \b/xms);
use constant _OPTIMIZE => scalar(($DEBUG =~ /\b optimize=(\d+) \b/xms)[0]);

our @CARP_NOT = qw(Text::Xslate Text::Xslate::Parser);

my %binary = (
    '==' => 'eq',
    '!=' => 'ne',
    '<'  => 'lt',
    '<=' => 'le',
    '>'  => 'gt',
    '>=' => 'ge',

    '+'  => 'add',
    '-'  => 'sub',
    '*'  => 'mul',
    '/'  => 'div',
    '%'  => 'mod',

    '~'  => 'concat',

    'min' => 'lt', # a < b ? a : b
    'max' => 'gt', # a > b ? a : b

    '['  => 'fetch_field',
);
my %logical_binary = (
    '&&'  => 'and',
    'and' => 'and',
    '||'  => 'or',
    'or'  => 'or',
    '//'  => 'dor',
);

my %unary = (
    '!'   => 'not',
    'not' => 'not',
    '+'   => 'plus',
    '-'   => 'minus',
);

has optimize => (
    is  => 'rw',
    isa => 'Int',

    default => _OPTIMIZE // 3,
);

has lvar_id => ( # local varialbe id
    is  => 'rw',
    isa => 'Int',

    traits  => [qw(Counter)],
    handles => {
        lvar_use     => 'inc',
        lvar_release => 'dec',
    },

    default  => 0,
    init_arg => undef,
);

has lvar => ( # local varialbe id table
    is  => 'rw',
    isa => 'HashRef[Int]',

    default  => sub{ {} },
    init_arg => undef,
);

has macro_table => (
    is  => 'rw',
    isa => 'HashRef',

    init_arg => undef,
);

has engine => (
    is  => 'ro',
    isa => 'Object', # Text::Xslate

    weak_ref => 1,

    required => 0,
);

has syntax => (
    is  => 'rw',
    isa => 'Str|Object',

    default  => 'Kolon',
    required => 0,
);

has escape_mode => (
    is  => 'rw',
    isa => enum([qw(html none)]),

    default => 'html',
);

has parser => (
    is  => 'rw',
    isa => 'Object', # Text::Xslate::Parser

    handles => [qw(file line define_constant define_function)],

    lazy    => 1,
    default => sub {
        my($self) = @_;
        my $syntax = $self->syntax;
        if(ref $syntax) {
            return $syntax;
        }
        else {
            my $parser_class = Any::Moose::load_first_existing_class(
                "Text::Xslate::Syntax::" . $syntax,
                $syntax,
            );
            return $parser_class->new();
        }
    },

    required => 0,
);

has cascade => (
    is  => 'rw',
    isa => 'Object',
);

sub compile {
    my($self, $str, %args) = @_;

    my %mtable;
    local $self->{macro_table} = \%mtable;
    local $self->{cascade};

    my $parser   = $self->parser;
    my $old_file = $parser->file;

    my @code; # main protocode
    {
        my $ast = $parser->parse($str, %args);

        @code = $self->_compile_ast($ast);
        push @code, ['end'];
    }

    my $cascade = $self->cascade;
    if(defined $cascade) {
        my $engine = $self->engine
            // $self->_error("Cannot cascade templates without Xslate engine", $cascade);

        my($base_file, $base_code);
        my $base       = $cascade->first;
        my @components = $cascade->second
            ? (map{ $self->_bare_to_file($_) } @{$cascade->second})
            : ();
        my $vars       = $cascade->third;

        if(defined $base) {
            $base_file = $self->_bare_to_file($base);
            $base_code = $base_code = $engine->load_file($base_file);
            unshift @{$base_code},
                [ depend => $engine->find_file($base_file)->{fullpath} ];
        }
        else { # only "with"
            $base_file = $args{file} // '<input>'; # only for error messages
            $base_code = \@code;

            if(defined $args{fullpath}) {
                unshift @{$base_code},
                    [ depend => $args{fullpath} ];
            }

            push @code, $self->_flush_macro_table(\%mtable);
        }

        # overlay:
        foreach my $cfile(@components) {
            my $body;
            my $code     = $engine->load_file($cfile);
            my $fullpath = $engine->find_file($cfile)->{fullpath};

            foreach my $c(@{$code}) {
                if($c->[0] eq 'macro_begin' .. $c->[0] eq 'macro_end') {
                    if($c->[0] eq 'macro_begin') {
                        $body = [];
                        push @{ $mtable{$c->[1]} //= [] }, {
                            name  => $c->[1],
                            line  => $c->[2],
                            body  => $body,
                        };
                    }
                    elsif($c->[0] ne 'macro_end') {
                        push @{$body}, $c;
                    }
                }
            }

            unshift @{$base_code},
                [ depend => $fullpath ];
            @{$base_code} = $self->_process_cascade($cfile, $base_code);
            ### after: $base_code
        }

        # pure cascade:
        @{$base_code} = $self->_process_cascade($base_file, $base_code)
            if defined $base;

        if(defined $vars) {
            unshift @{$base_code}, $self->_localize_vars($vars);
        }

        # discards all the main code (if should so)
        if($base_code != \@code) {
            foreach my $c(@code) {
                if(!($c->[0] eq 'print_raw_s' && $c->[1] =~ m{\A [ \t\r\n]* \z}xms)) {
                    if($c->[0] eq 'print_raw_s') {
                        Carp::carp("Xslate: Uselses use of text '$c->[1]'");
                    }
                    else {
                        #Carp::carp("Xslate: Useless use of $c->[0] " . ($c->[1] // ""));
                    }
                }
            }
            @code = @{$base_code};
        }
    } # if defined $cascade

    push @code, $self->_flush_macro_table(\%mtable) if %mtable;

    $self->_optimize_vmcode(\@code) for 1 .. $self->optimize;

    print "// ", $self->file, "\n",
        $self->as_assembly(\@code, scalar($DEBUG =~ /\b addix \b/xms))
            if _DUMP_ASM;

    $parser->file($old_file // '<input>'); # reset

    return \@code;
}

sub _flush_macro_table {
    my($self, $mtable) = @_;
    my @code;
    foreach my $macros(values %{$mtable}) {
        foreach my $macro(ref($macros) eq 'ARRAY' ? @{$macros} : $macros) {
            push @code, [ 'macro_begin', $macro->{name}, $macro->{line} ];
            push @code, @{ $macro->{body} };
            push @code, [ 'macro_end' ];
        }
    }
    %{$mtable} = ();
    return @code;
}

sub _compile_ast {
    my($self, $ast) = @_;
    return unless defined $ast;

    Carp::croak("Oops: Not an ARRAY reference: " . p($ast)) if ref($ast) ne 'ARRAY';

    # TODO
    # $self->_optimize_ast($ast) if $self->optimize;

    my @code;
    foreach my $node(@{$ast}) {
        blessed($node) or Carp::croak("Oops: Not a node object: " . p($node));
        my $generator = $self->can('_generate_' . $node->arity)
            || Carp::croak("Oops: Unexpected node:  " . p($node));

        push @code, $self->$generator($node);
    }

    return @code;
}

sub _process_cascade {
    my($self, $base_file, $base_code) = @_;
    my $mtable = $self->macro_table;

    my @code = @{$base_code};
    for(my $i = 0; $i < @code; $i++) {
        my $c = $code[$i];
        if($c->[0] ne 'macro_begin') {
            next;
        }

        # macro
        my $name = $c->[1];
        #warn "macro ", $name, "\n";

        if(exists $mtable->{$name}) {
            $self->_error(
                "Redefinition of macro/block $name in " . $base_file
                . " (you must use before/around/after to override macros/blocks)",
                $mtable->{$name}{line}
            );
        }

        my $before = delete $mtable->{$name . '@before'};
        my $around = delete $mtable->{$name . '@around'};
        my $after  = delete $mtable->{$name . '@after'};

        if(defined $before) {
            my $n = scalar @code;
            foreach my $m(@{$before}) {
                splice @code, $i+1, 0, @{$m->{body}};
            }
            $i += scalar(@code) - $n;
        }

        my $macro_start = $i+1;
        $i++ while($code[$i][0] ne 'macro_end'); # move to the end

        if(defined $around) {
            my @original = splice @code, $macro_start, ($i - $macro_start);
            $i = $macro_start;

            my @body;
            foreach my $m(@{$around}) {
                push @body, @{$m->{body}};
            }
            for(my $j = 0; $j < @body; $j++) {
                if($body[$j][0] eq 'super') {
                    splice @body, $j, 1, @original;
                }
            }
            splice @code, $macro_start, 0, @body;

            $i += scalar(@body);
        }

        if(defined $after) {
            foreach my $m(@{$after}) {
                splice @code, $i, 0, @{$m->{body}};
            }
        }
    }
    return @code;
}

{
    package Text::Xslate;
    our %OPS; # to avoid 'once' warnings;
}

sub _can_print_optimize {
    my($self, $name, $arg) = @_;

    return 0 if !($name eq 'print' or $name eq 'print_raw');

    return $arg->id eq '|'
        && $arg->second->arity eq 'function'
        && $arg->second->id    ~~ [qw(raw html)];
}

sub _generate_name {
    my($self, $node) = @_;

    $self->_error("Undefined symbol '$node', before " . $node->first, $node);
}

sub _generate_command {
    my($self, $node) = @_;

    my @code;

    my $proc = $node->id;
    if($proc eq 'print' and $self->escape_mode ne 'html') {
        $proc = 'print_raw';
    }

    my $do_optimize = ($self->optimize > 0);

    foreach my $arg(@{ $node->first }){
        if(exists $Text::Xslate::OPS{$proc . '_s'} && $arg->arity eq 'literal'){
            push @code, [ $proc . '_s' => literal_to_value($arg->value), $node->line ];
        }
        elsif($do_optimize and $self->_can_print_optimize($proc, $arg)){
            # expr | html
            # expr | raw
            my $command = $arg->second->id eq 'html' ? 'print' : 'print_raw';
            push @code,
                $self->_generate_expr($arg->first),
                [ $command => undef, $node->line, "builtin filter" ];
        }
        else {
            push @code,
                $self->_generate_expr($arg),
                [ $proc => undef, $node->line ];
        }
    }
    if(defined(my $vars = $node->second)) {
        @code = (['enter'], $self->_localize_vars($vars), @code, ['leave']);
    }

    if(!@code) {
        $self->_error("$node requires at least one argument", $node);
    }
    return @code;
}

sub _bare_to_file {
    my($self, $file) = @_;
    if(ref($file) eq 'ARRAY') { # myapp::foo
        $file  = join '/', @{$file};
        $file .= $self->engine->{suffix};
    }
    else { # "myapp/foo.tx"
        $file = literal_to_value($file);
    }
    return $file;
}

sub _generate_cascade {
    my($self, $node) = @_;
    if(defined $self->cascade) {
        $self->_error("Cannot cascade twice in a template", $node);
    }
    $self->cascade( $node );
    return ();
}

sub _generate_for {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} != 1) {
        $self->_error("A for-loop requires single variable for each items", $node);
    }
    my @code = $self->_generate_expr($expr);

    my($iter_var) = @{$vars};
    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $iter_var->id;

    local $self->lvar->{$lvar_name} = [ fetch_lvar => $lvar_id, undef, $lvar_name ];

    push @code, [ for_start => $lvar_id, $expr->line, $lvar_name ];

    # a for statement uses three local variables (container, iterator, and item)
    $self->lvar_use(3);
    my @block_code = $self->_compile_ast($block);
    $self->lvar_release(3);

    push @code,
        [ literal_i => $lvar_id, $expr->line, $lvar_name ],
        [ for_iter  => scalar(@block_code) + 2 ],
        @block_code,
        [ goto      => -(scalar(@block_code) + 2), undef, "end for" ];

    return @code;
}

sub _generate_while {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} > 1) {
        $self->_error("A while-loop requires one or zero variable for each items", $node);
    }
    my @code = $self->_generate_expr($expr);

    my($iter_var) = @{$vars};
    my($lvar_id, $lvar_name);

    if(@{$vars}) {
        $lvar_id   = $self->lvar_id;
        $lvar_name = $iter_var->id;
    }

    local $self->lvar->{$lvar_name} = [ fetch_lvar => $lvar_id, undef, $lvar_name ]
        if @{$vars};

    # a for statement uses three local variables (container, iterator, and item)
    $self->lvar_use(scalar @{$vars});
    my @block_code = $self->_compile_ast($block);
    $self->lvar_release(scalar @{$vars});

    push @code, [ save_to_lvar => $lvar_id, $expr->line, $lvar_name ]
        if @{$vars};

    push @code,
        [ dand  => scalar(@block_code) + 2, undef, "while" ],
        @block_code,
        [ goto => -(scalar(@block_code) + scalar(@code) + 1), undef, "end while" ];

    return @code;
}

sub _generate_proc { # block, before, around, after
    my($self, $node) = @_;
    my $type   = $node->id;
    my $name   = $node->first;
    my @args   = map{ $_->id } @{$node->second};
    my $block  = $node->third;

    local @{ $self->lvar }{ @args };
    my $arg_ix = 0;
    foreach my $arg(@args) {
        # to fetch ST(ix)
        # Note that arg_ix must be start from 1
        $self->lvar->{$arg} = [ fetch_lvar => $arg_ix++, $node->line, $arg ];
    }

    $self->lvar_use($arg_ix);

    my %macro = (
        name   => $name,
        nargs  => $arg_ix,
        body   => [ $self->_compile_ast($block) ],
        line   => $node->line,
        file   => $self->file,
    );

    my @code;

    if($type ~~ [qw(macro block)]) {
        if(exists $self->macro_table->{$name}) {
            $self->_error("Redefinition of $type $name is found", $node);
        }
        $self->macro_table->{$name} = \%macro;
        if($type eq 'block') {
            @code = (
                [ pushmark  => () ],
                [ macro     => $name ],
                [ macrocall => undef ],
                [ print     => undef ],
            );
        }
    }
    else {
        my $fq_name = sprintf '%s@%s', $name, $type;
        $macro{name} = $fq_name;
        push @{ $self->macro_table->{ $fq_name } //= [] }, \%macro;
    }

    $self->lvar_release($arg_ix);

    return @code;
}

sub _generate_if {
    my($self, $node) = @_;

    my @expr  = $self->_generate_expr($node->first);
    my @then  = $self->_compile_ast($node->second);

    my $other = $node->third;
    my @else = blessed($other)
        ? $self->_generate_if($other)
        : $self->_compile_ast($other);

    return(
        @expr,
        [ and  => scalar(@then) + 2, undef, $node->id ],
        @then,
        [ goto => scalar(@else) + 1 ],
        @else,
    );
}

sub _generate_given {
    my($self, $node) = @_;
    my $expr  = $node->first;
    my $vars  = $node->second;
    my $block = $node->third;

    if(@{$vars} > 1) {
        $self->_error("A given block requires one or zero variables", $node);
    }
    my @code = $self->_generate_expr($expr);

    my($lvar) = @{$vars};
    my $lvar_id   = $self->lvar_id;
    my $lvar_name = $lvar->id;

    local $self->lvar->{$lvar_name} = [ fetch_lvar => $lvar_id, undef, $lvar_name ];

    # a for statement uses three local variables (container, iterator, and item)
    $self->lvar_use(1);
    my @block_code = $self->_compile_ast($block);
    $self->lvar_release(1);

    push @code, [ save_to_lvar => $lvar_id, undef, "given $lvar_name" ], @block_code;
    return @code;
}

sub _generate_expr {
    my($self, $node) = @_;
    my @ast = ($node);

    return $self->_compile_ast(\@ast);
}

sub _generate_variable {
    my($self, $node) = @_;

    my @fetch;
    if(defined(my $lvar_code = $self->lvar->{$node->id})) {
        @fetch = @{$lvar_code};
    }
    else {
        @fetch = ( fetch_s => $self->_variable_to_value($node) );
    }
    $fetch[2] = $node->line;
    return \@fetch;
}

sub _generate_marker {
    my($self, $node) = @_;

    return [ $node->id => undef, $node->line ];
}

sub _generate_literal {
    my($self, $node) = @_;

    my $value = literal_to_value($node->value);
    if(defined $value){
        return [ literal => $value ];
    }
    else {
        return [ nil => undef ];
    }
}

sub _generate_objectliteral {
    my($self, $node) = @_;

    my $list = $node->first;
    my $type = $node->id eq '{' ? 'make_hash' : 'make_array';

    return
        ['pushmark', undef, undef, $type],
        (map{ $self->_generate_expr($_), ['push'] } @{$list}),
        [$type],
    ;
}

sub _generate_unary {
    my($self, $node) = @_;

    given($node->id) {
        when(%unary) {
            return
                $self->_generate_expr($node->first),
                [ $unary{$_} => () ];
        }
        default {
            $self->_error("Unary operator $_ is not implemented", $node);
        }
    }
}

sub _generate_binary {
    my($self, $node) = @_;

    given($node->id) {
        when('.') {
            return
                $self->_generate_expr($node->first),
                [ fetch_field_s => $node->second->id ];
        }
        when('|') {
            # a | b -> b(a)
            return $self->_generate_call($node->clone(
                first  =>  $node->second,
                second => [$node->first],
            ));
        }
        when(%binary) {
            # eval lhs
            my @code = $self->_generate_expr($node->first);
            push @code, [ save_to_lvar => $self->lvar_id ];

            # eval rhs
            $self->lvar_use(1);
            push @code, $self->_generate_expr($node->second);
            $self->lvar_release(1);

            # execute op
            push @code,
                [ load_lvar_to_sb => $self->lvar_id ],
                [ $binary{$_}   => undef ];

            if($_ ~~ [qw(min max)]) {
                splice @code, -1, 0,
                    [save_to_lvar => $self->lvar_id ]; # save lhs
                push @code,
                    [ or              => +2 , undef, undef, $_ ],
                    [ load_lvar_to_sb => $self->lvar_id ], # on false
                    # fall through
                    [ move_from_sb    => () ],             # on true
            }
            return @code;
        }
        when(%logical_binary) {
            my @right = $self->_generate_expr($node->second);
            return
                $self->_generate_expr($node->first),
                [ $logical_binary{$_} => scalar(@right) + 1 ],
                @right;
        }
        default {
            $self->_error("Binary operator $_ is not implemented", $node);
        }
    }
    return;
}

sub _generate_ternary { # the conditional operator
    my($self, $node) = @_;
    my @expr = $self->_generate_expr($node->first);
    my @then = $self->_generate_expr($node->second);
    my @else = $self->_generate_expr($node->third);
    return(
        @expr,
        [ and  => scalar(@then) + 2, $node->line, 'ternary' ],
        @then,
        [ goto => scalar(@else) + 1 ],
        @else,
    );
}

sub _generate_methodcall {
    my($self, $node) = @_;
    my $args   = $node->third;
    my $method = $node->second->id;
    return (
        [ pushmark => undef, undef, $method ],
        $self->_generate_expr($node->first),
        [ 'push' ],
        (map { $self->_generate_expr($_), [ 'push' ] } @{$args}),
        [ methodcall_s => $method ],
    );
}

sub _generate_call {
    my($self, $node) = @_;
    my $callable = $node->first; # function or macro
    my $args     = $node->second;

    my @code = (
        [ pushmark => undef, undef, $callable->id ],
        (map { $self->_generate_expr($_), [ 'push' ] } @{$args}),
        $self->_generate_expr($callable),
    );

    if($code[-1][0] eq 'macro') {
        push @code, [ macrocall => undef, $node->line ];
    }
    else {
        push @code, [ funcall => undef, $node->line ];
    }
    return @code;
}

sub _generate_function {
    my($self, $node) = @_;

    return [ function => $node->value ];
}

sub _generate_macro {
    my($self, $node) = @_;

    return [ macro => $node->value ];
}

sub _localize_vars {
    my($self, $vars) = @_;
    my @local_vars;
    foreach my $pair(@{$vars}) {
        my($key, $expr) = @{$pair};
        push @local_vars,
            $self->_generate_expr($expr),
            [ local_s => $key ];
        ;
    }
    return @local_vars;
}

sub _variable_to_value {
    my($self, $arg) = @_;

    my $name = $arg->value;
    $name =~ s/\$//;
    return $name;
}

my %goto_family;
@goto_family{qw(
    for_iter
    and
    or
    dor
    goto
)} = ();

sub _noop {
    my($op) = @_;
    @{$op} = (noop => undef, undef, "ex-$op->[0]");
    return;
}

sub _optimize_vmcode {
    my($self, $c) = @_;

    # calculate goto addresses
    # eg:
    #
    # goto +3
    # foo
    # noop
    # bar // goto destination
    #
    # to be:
    #
    # goto +2
    # foo
    # bar // goto destination

    my @goto_addr;
    for(my $i = 0; $i < @{$c}; $i++) {
        if(exists $goto_family{ $c->[$i][0] }) {
            my $addr = $c->[$i][1]; # relational addr

            # mark ragens that goto family have its effects
            my @range = $addr > 0
                ? ($i .. ($i+$addr-1))  # positive
                : (($i+$addr) .. $i); # negative

            foreach my $j(@range) {
                push @{$goto_addr[$j] //= []}, $c->[$i];
            }
        }
    }

    for(my $i = 0; $i < @{$c}; $i++) {
        given($c->[$i][0]) {
            when('print_raw_s') {
                # merge a chain of print_raw_s into single command
                my $j = $i + 1; # from the next op
                while($j < @{$c}
                        && $c->[$j][0] eq 'print_raw_s'
                        && "@{$goto_addr[$i] // []}" eq "@{$goto_addr[$j] // []}") {

                    $c->[$i][1] .= $c->[$j][1];

                    _noop($c->[$j]);
                    $j++;
                }
            }
            when('save_to_lvar') {
                # use registers, instead of local variables
                #
                # given:
                #   save_to_lvar $n
                #   <single-op>
                #   load_lvar_to_sb $n
                # convert into:
                #   move_to_sb
                #   <single-op>
                my $it = $c->[$i];
                my $nn = $c->[$i+2]; # next next
                if(defined($nn)
                    && $nn->[0] eq 'load_lvar_to_sb'
                    && $nn->[1] == $it->[1]) {
                    @{$it} = ('move_to_sb', undef, undef, "ex-$it->[0]");

                    _noop($nn);
                }
            }
            when('literal') {
                if(is_int($c->[$i][1])) {
                    $c->[$i][0] = 'literal_i';
                }
            }
            when('fetch_field') {
                my $prev = $c->[$i-1];
                if($prev->[0] =~ /^literal/) { # literal or literal_i
                    $c->[$i][0] = 'fetch_field_s';
                    $c->[$i][1] = $prev->[1];

                    _noop($prev);
                }
            }
        }
    }

    # remove noop
    for(my $i = 0; $i < @{$c}; $i++) {
        if($c->[$i][0] eq 'noop') {
            if(defined $goto_addr[$i]) {
                foreach my $goto(@{ $goto_addr[$i] }) {
                    # reduce its absolute value
                    $goto->[1] > 0
                        ? $goto->[1]--  # positive
                        : $goto->[1]++; # negative
                }
            }
            splice @{$c}, $i, 1;
            # adjust @goto_addr, but it may be empty
            splice @goto_addr, $i, 1 if @goto_addr > $i;
        }
    }
    return;
}

sub as_assembly {
    my($self, $code_ref, $addix) = @_;

    my $as = "";
    foreach my $ix(0 .. (@{$code_ref}-1)) {
        my($opname, $arg, $line, $comment) = @{$code_ref->[$ix]};
        $as .= "$ix:" if $addix; # for debugging

        # "$opname $arg #$line // $comment"
        $as .= $opname;
        if(defined $arg) {
            $as .= " ";

            if(Scalar::Util::looks_like_number($arg)){
                $as .= $arg;
            }
            else {
                $arg =~ s/\\/\\\\/g;
                $arg =~ s/\n/\\n/g;
                $arg =~ s/\r/\\r/g;
                $arg =~ s/"/\\"/g;
                $as .= qq{"$arg"};
            }
        }
        if(defined $line) {
            $as .= " #$line";
        }
        if(defined $comment) {
            $as .= " // $comment";
        }
        $as .= "\n";
    }
    return $as;
}

sub _error {
    my($self, $message, $node) = @_;

    my $line = ref($node) ? $node->line : $node;
    Carp::croak(sprintf 'Xslate::Compiler(%s:%d): %s', $self->file, $line, $message);
}

no Any::Moose;
no Any::Moose '::Util::TypeConstraints';

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Text::Xslate::Compiler - The Xslate compiler

=head1 DESCRIPTION

This is the Xslate compiler to generate the virtual machine code from the abstract syntax tree.

=head1 SEE ALSO

L<Text::Xslate>

=cut
