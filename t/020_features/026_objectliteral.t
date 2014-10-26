#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use Text::Xslate::Util qw(p);
use t::lib::Util;

my $tx = Text::Xslate->new(path => [path]);

my @set = (
    [<<'T', { lang => 'Xslate' }, <<'X', "=> as ,"],
: macro foo -> $a, $b { $a ~ "\n" }
: foo("foo" => "b")
T
foo
X

    [<<'T', { lang => 'Xslate' }, <<'X', "lhs can be bare"],
: macro foo -> $a, $b { $a ~ "\n" }
: foo(foo => "b")
: foo(bar => "b")
: foo(raw => "b")
: foo(if  => "b")
T
foo
bar
raw
if
X

    # array

    [<<'T', { lang => 'Xslate' }, '0', "empty array literal"],
: macro foo -> $a { $a.size() }
: foo([])
T

    [<<'T', { lang => 'Xslate' }, <<'X', "array literal"],
: macro foo -> $a { $a.0 ~ "\n" }
: foo(["foo", "bar", "baz"])
T
foo
X

    [<<'T', { lang => 'Xslate' }, <<"X"],
: for [1, 2, 3] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ["foo", $lang].1
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: (["foo", $lang]).1
T

    # hash

    [<<'T', { lang => 'Xslate' }, '0', "empty hash literal"],
: macro foo -> $a { $a.size() }
: foo({})
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ({foo => $lang, bar => 42}).foo
T

    [<<'T', { lang => 'Xslate' }, "Xslate"],
: ({ bar => 42, foo => $lang }).foo
T

    [<<'T', { lang => 'Xslate' }, <<"X"],
: for { foo => 10, bar => 20 }.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
: }
T
    bar=20
    foo=10
X

    [<<'T', { lang => 'Xslate' }, <<"X", "keywords"],
: for { not => 10, for => 20 }.kv() -> $pair {
    <: $pair.key :>=<: $pair.value :>
: }
T
    for=20
    not=10
X

    [<<'T', { lang => 'Xslate' }, <<"X", "nested"],
: for [ [1], [2], [3] ] -> $i {
    <: $i[0] :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "nested"],
: for [ { value => 1 }, { value => 2 }, { value => 3 } ] -> $i {
    <: $i.value :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "extra commas"],
: for [ 1, 2, 3, ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "newlines"],
: for [
:        1,
:        2,
:        3,
:    ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

    [<<'T', { lang => 'Xslate' }, <<"X", "more extra commas"],
: for [ ,,1,,2,,3,, ] -> $i {
    <: $i :>
: }
T
    1
    2
    3
X

);

foreach my $d(@set) {
    my($in, $vars, $out, $msg) = @$d;

    is $tx->render_string($in, $vars), $out, $msg
        or diag($in);
}


done_testing;
