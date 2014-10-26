#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Compiler;
use Text::Xslate::Parser;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <:= $foo $bar :> world!
T
};
like $@, qr/Parser/;
like $@, qr/\$foo/;
like $@, qr/\$bar/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <:= xyzzy :> world!
T
};
like $@, qr/\b xyzzy \b/xms;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: if $lang { :> world!
T
};
like $@, qr/Parser/;
like $@, qr/Expected "}"/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: } :> world!
T
};
like $@, qr/Parser/;
like $@, qr/\}/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: if $foo { ; } } :> world!
T
};
like $@, qr/Parser/;
like $@, qr/\}/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: $foo <> $bar :> world!
T
};
like $@, qr/Parser/;
like $@, qr/\$bar/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> ($var { ; }
T
};
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> $var) { ; }
T
};
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> ($x $y) { ; }
T
};
like $@, qr/Parser/;
like $@, qr/\$y/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: macro foo -> "foo" { ; }
T
};
like $@, qr/Parser/;
like $@, qr/"foo"/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
Hello, <: "Xslate' :> world! # unmatched quote
T
}; # " for poor editors
like $@, qr/Parser/;
like $@, qr/Malformed/;
like $@, qr/"Xslate'/; # " for poor editors

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
Hello, <: foo(42 :>
T
};
unlike $@, qr/;/, q{don't include ";"}; # '
like $@, qr/Expected "\)"/;
like $@, qr/Parser/;


eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: constant FOO = 42;
: constant FOO = 42;
T
};
like $@, qr/Already defined/;
like $@, qr/\b FOO \b/xms;
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: constant FOO = 42;
: FOO = 42
T
};
like $@, qr/\b FOO \b/xms;
like $@, qr/Parser/;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: if( constant FOO = 42 ) { }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: for $data -> $i { constant FOO = 42 }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: while constant FOO = 42 {  }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
: given constant FOO = 42 {  }
: FOO
T
};
like $@, qr/Undefined symbol/;
like $@, qr/\b FOO \b/xms;

foreach my $op(qw(++ --)) {
    # reserved, but dosn't work
    eval {
        Text::Xslate::Compiler->new->compile(<<"T");
        Hello, <: $op\$foo :> world!
T
    };
    like $@, qr/\Q$op\E/, "operator $op";
}

foreach my $assign(qw(= += -= *= /= %= ~= &&= ||= //=)) {
    eval {
        Text::Xslate::Compiler->new->compile(<<"T");
        Hello, <: \$foo $assign 42 :> world!
T
    };
    like $@, qr/Parser/, "assignment ($assign)";
    like $@, qr/\Q$assign/;
    like $@, qr/\$foo/;
}

eval {
    Text::Xslate::Compiler->new->compile(<<'T');
    Hello, <: foo() :> world!
T
};
like $@, qr/Compiler/;
like $@, qr/\b foo \b/xms;

done_testing;
