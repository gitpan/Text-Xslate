#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Parser;

my $tx = Text::Xslate->new( cache => 0 );

# parse/compile errors

eval {
    $tx->render_string(<<'T');
    Hello, <:= $foo $bar :> world!
T
};
like $@, qr/\$foo/;
like $@, qr/\$bar/;

eval {
    $tx->render_string(<<'T');
    Hello, <:= xyzzy :> world!
T
};
like $@, qr/\b xyzzy \b/xms;

eval {
    $tx->render_string(<<'T');
    Hello, <: if $lang { :> world!
T
};
like $@, qr/Expected "}"/;

eval {
    $tx->render_string(<<'T');
    Hello, <: } :> world!
T
};
like $@, qr/\}/;

eval {
    $tx->render_string(<<'T');
    Hello, <: if $foo { ; } } :> world!
T
};
like $@, qr/\}/;

eval {
    $tx->render_string(<<'T');
    Hello, <: $foo <> $bar :> world!
T
};
like $@, qr/\$bar/;

eval {
    $tx->render_string(<<'T');
: macro foo -> ($var { ; }
T
};
like $@, qr/Expected "\)"/;

eval {
    $tx->render_string(<<'T');
: macro foo -> $var) { ; }
T
};
like $@, qr/\$var/;

eval {
    $tx->render_string(<<'T');
: macro foo -> ($x $y) { ; }
T
};
like $@, qr/\$y/;

eval {
    $tx->render_string(<<'T');
: macro foo -> "foo" { ; }
T
};
like $@, qr/"foo"/;

eval {
    $tx->render_string(<<'T');
Hello, <: "Xslate' :> world! # unmatched quote
T
}; # " for poor editors
like $@, qr/Malformed/;
like $@, qr/"Xslate'/; # " for poor editors

eval {
    $tx->render_string(<<'T');
Hello, <: foo(42 :>
T
};
unlike $@, qr/;/, q{don't include ";"}; # '
like $@, qr/Expected "\)"/;

# semantics errors

eval {
    $tx->render_string(<<'T');
: constant FOO = 42;
: constant FOO = 42;
T
};
like $@, qr/Already defined/;
like $@, qr/\b FOO \b/xms;

eval {
    $tx->render_string(<<'T');
: constant FOO = 42;
: FOO = 42
T
};
like $@, qr/\b FOO \b/xms;

eval {
    $tx->render_string(<<'T');
: if( constant FOO = 42 ) { }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    $tx->render_string(<<'T');
: for $data -> $i { constant FOO = 42 }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    $tx->render_string(<<'T');
: while (constant FOO = 42) == 0 {  }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    $tx->render_string(<<'T');
: given constant FOO = 42 {  }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

foreach my $op(qw(++ --)) {
    # reserved, but dosn't work
    eval {
        $tx->render_string(<<"T");
        Hello, <: $op\$foo :> world!
T
    };
    like $@, qr/\Q$op\E/, "operator $op";
}

foreach my $assign(qw(= += -= *= /= %= ~= &&= ||= //=)) {
    eval {
        $tx->render_string(<<"T");
        Hello, <: \$foo $assign 42 :> world!
T
    };
    like $@, qr/\Q$assign/, "assignment ($assign)";
    like $@, qr/\$foo/;
}

eval {
    $tx->render_string(<<'T');
    Hello, <: foo() :> world!
T
};
like $@, qr/\b foo \b/xms;

foreach my $iter(qw($~foo $~foo.index $~foo.count $~foo.is_first $~foo.is_last)) {
    eval {
        $tx->render_string("<: $iter :>");
    };
    like $@, qr/\$~foo/, $iter;
}

eval {
    $tx->render_string('<: for $data -> $i { $i~.foobar } :>');
};
like $@, qr/\b foobar \b/xms;

done_testing;
