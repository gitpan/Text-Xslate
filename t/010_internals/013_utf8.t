#!perl -w
use strict;
use Test::More;

use Text::Xslate;
use utf8;

use FindBin qw($Bin);
use t::lib::Util;

END { unlink "$Bin/../template/hello_utf8.txc"; }

my $tx = Text::Xslate->new(
    path      => [path],
    cache_dir =>  path,
);


is $tx->render_string(<<'T', { value => "エクスレート" }),
ようこそ <:= $value :> の世界へ！
T
    "ようこそ エクスレート の世界へ！\n", "utf8";

is $tx->render_string(<<'T', { value => "Xslate" }),
ようこそ <:= $value :> の世界へ！
T
    "ようこそ Xslate の世界へ！\n", "utf8";


is $tx->render_string(<<'T'), <<'X', 'macro';
: macro lang -> { "エクスレート" }
ようこそ <:= lang() :> の世界へ！
T
ようこそ エクスレート の世界へ！
X


is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
    "こんにちは！ エクスレート！\n", "in files" for 1 .. 2;

for(1 .. 2) {
    $tx = Text::Xslate->new(
        path        => [path],
        cache_dir   =>  path,
        input_layer => ":encoding(utf-8)",
    );

    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", "encoding(utf-8)";
}

unlink "$Bin/../template/hello_utf8.txc";

for(1 .. 2) {
    no utf8;
    $tx = Text::Xslate->new(
        path        => [path],
        cache_dir   =>  path,
        input_layer => ":bytes",
    );
    #use Devel::Peek; Dump($tx->render("hello_utf8.tx", { name => "エクスレート" }));
    is $tx->render("hello_utf8.tx", { name => "エクスレート" }),
        "こんにちは！ エクスレート！\n", ":bytes";
}

done_testing;
