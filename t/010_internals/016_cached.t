#!perl -w

use strict;
use Test::More;

use Text::Xslate;
use File::Path;

rmtree('t/template/cache');
END{ rmtree('t/template/cache') }

is system($^X, (map { "-I$_" } @INC), "-we", <<'EOT'), 0, 'compile' or die;
    BEGIN{ ($ENV{XSLATE} ||= '') =~ s/dump//g; }
    use Text::Xslate;
    my $tx = Text::Xslate->new(
        cache_dir => 't/template/cache',
        path      => ['t/template', { 'foo.tx' => 'Hello' } ],
   );
   $tx->load_file('myapp/derived.tx');
   $tx->load_file('foo.tx');
EOT
ok -d 't/template/cache', '-d "t/template/cache"';

for my $cache(1 .. 2) {
    my $tx = Text::Xslate->new(
        path      => ['t/template', { 'foo.tx' => 'Hello' } ],
        cache_dir => 't/template/cache',
        cache     => $cache,
    );

    for(1 .. 2) {
        like $tx->render('myapp/derived.tx', { lang => 'Xslate' }),
            qr/Hello, Xslate world!/, "cache => $cache";

        is $tx->render('foo.tx'), 'Hello';

        ok !exists $INC{'Text/Xslate/Compiler.pm'}, 'Text::Xslate::Compiler is not loaded';
    }
}

done_testing;
