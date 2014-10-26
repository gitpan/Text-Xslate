#!perl -w

use strict;

use Test::Requires qw(Test::LeakTrace);
use Test::More;
use Text::Xslate;
use t::lib::Util;

use if Text::Xslate->isa('Text::Xslate::PP'),
    'Test::More' => skip_all => 'PP will be safe';

my %vars = (
    lang  => 'Perl',
    my    => { lang => 'Xslate' },
    data  => [ { title => 'foo' }, { title => 'bar' } ],
    value => 32,
);

if(0) { # TODO
    no_leaks_ok {
        my $tx  = Text::Xslate->new(path => [path], cache => 0);
        my $out = $tx->render('hello.tx', \%vars);
        $out eq "Hello, Perl world!\n" or die "Error: [$out]";
    } "new() and render()" or die;
}

my @set = (
    [<<'T', <<'X', 'interpolate'],
        Hello, <:= $my.lang :> world!
T
        Hello, Xslate world!
X

    [<<'T', <<'X', 'for'],
        : for $data -> ($item) {
            [<:= $item.title :>]
        : }
T
            [foo]
            [bar]
X

    [<<'T', <<'X', 'expr'],
        <:= ($value + 10) * 2 :>
T
        84
X

    [<<'T', <<'X', 'expr'],
        <:= ($value - 10) / 2 :>
T
        11
X

    [<<'T', <<'X', 'expr'],
        <:= $value % 2 :>
T
        0
X

    [<<'T', <<'X', 'expr'],
        <:= "|" ~ $my.lang ~ "|" :>
T
        |Xslate|
X

    [<<'T', <<'X', 'expr'],
        <:= $value > 10 ? "larger than 10" : "equal or smaller than 10" :>
T
        larger than 10
X

    [<<'T', <<'X', 'chained max'],
        <:= $value max 100 max 200 :>
T
        200
X

    [<<'T', <<'X', 'chainded min'],
        <:= $value min 100 min 200 :>
T
        32
X

    [<<'T', <<'X', 'filter'],
        <:= $my.lang | uc :>
T
        XSLATE
X

    [<<'T', <<'X', 'funcall'],
        <:= uc($my.lang) :>
T
        XSLATE
X

    [<<'T', <<'X', 'block'],
    : block hello -> {
        Hello, <: $my.lang :> world!
    : }
T
        Hello, Xslate world!
X

    [<<'T', <<'X', 'array literal'],
    : for ["Xslate", "Perl"] -> $i {
        Hello, <: $i :> world!
    : }
T
        Hello, Xslate world!
        Hello, Perl world!
X

    [<<'T', <<'X', 'hash literal'],
    Hello, <: ({ lang => "Xslate" }).lang :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'builtin method for array'],
    Hello, <: ['C', 'B', 'A'].reverse().join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for array'],
    Hello, <: ['C', 'B', 'A'].sort().join(" ") :> world!
T
    Hello, A B C world!
X

    [<<'T', <<'X', 'builtin method for hash'],
    Hello, <: ({ lang => "Xslate" }).values().join(",") :> world!
T
    Hello, Xslate world!
X

    [<<'T', <<'X', 'builtin method for hash'],
    Hello, <: ({ "Xslate" => 42 }).keys().join(",") :> world!
T
    Hello, Xslate world!
X

);

my $tx = Text::Xslate->new(
    path     => [path],
    cache    => 0,
    function => {
        uc => sub { uc $_[0] },
    },
);
foreach my $d(@set) {
    my($in, $out, $msg) = @$d;

    $tx->load_string($in);

    no_leaks_ok {
        my $result = $tx->render(undef, \%vars);

        $result eq $out or die <<"MSG"
Error
Expected: [$out]
Got:      [$result]
MSG
    } $msg;
}

done_testing;
