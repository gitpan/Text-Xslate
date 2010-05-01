#!perl -w
use strict;
use Test::More;

use Text::Xslate::Compiler;

#use Data::Dumper; $Data::Dumper::Indent = 1;

my $tx = Text::Xslate::Compiler->new();

my @data = (
    [': if $lang {
ok
: }
: else {
not ok
: }
'
        => "ok\n", "if-else"],

    [': if !$lang {
ok
: }
: else {
not ok
: }
'
        => "not ok\n"],

    [': if($lang){
ok
: }
: else {
not ok
: }
'
        => "ok\n"],

    [': if(!$lang){
ok
: }
: else {
not ok
: }
'
        => "not ok\n"],


    [': if $lang {
ok
: }
!'
        => "ok\n!"],

    [': if $void {
ok
: }
!'
        => "!"],

    [': if !$void {
ok
: }
!'
        => "ok\n!"],

    [': if $lang {
a
: }
: else if $lang {
b
: }
!'
        => "a\n!"],

    [': if !$lang {
a
: }
: else if $lang {
b
: }
!'
        => "b\n!"],

    [<<'T', <<'X', "if-elsif-end (1)"],
: if $lang == "Xslate" {
    foo
: }
: else if $value == 10 {
    bar
: }
: else {
    baz
: }
T
    foo
X

    [<<'T', <<'X', "if-elsif-end (2)"],
: if $lang != "Xslate" {
    foo
: }
: else if $value == 10 {
    bar
: }
: else {
    baz
: }
T
    bar
X

    [<<'T', <<'X', "if-elsif-end (3)"],
: if $lang != "Xslate" {
    foo
: }
: else if $value != 10 {
    bar
: }
: else {
    baz
: }
T
    baz
X

);

foreach my $d(@data) {
    my($in, $out, $msg) = @$d;

    my $x = $tx->compile_str($in);

    my %vars = (
        lang => 'Xslate',
        void => '',

        value => 10,
    );
    is $x->render(\%vars), $out, $msg or diag($in);
    is $x->render(\%vars), $out;
}

done_testing;
