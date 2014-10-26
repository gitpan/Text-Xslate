#!perl -w
# test example/*.pl

use strict;
use Test::Requires 'IPC::Run';
use Test::More;

use IPC::Run qw(run timeout);
use File::Path qw(rmtree);

rmtree '.eg_cache';
END{ rmtree '.eg_cache' }

sub perl {
    # We cannot use IPC::Open3 simply.
    # See also http://d.hatena.ne.jp/kazuhooku/20100813/1281690025
    run [ $^X, (map { "-I$_" } @INC), @_ ],
        \my $in, \my $out, \my $err, timeout(5);

    foreach my $s($out, $err) { # for Win32
       $s =~ s/\r\n/\n/g;
    }

    return($out, $err);
}

EXAMPLE: while(defined(my $example = <example/*.pl>)) {
    my $expect = do {
        my $gold = $example;
        $gold =~ s/\.pl$/.gold/;

        -e $gold or note("skip $example because it has no $gold"), next;

        open my $g, '<', $gold or die "Cannot open '$gold' for reading: $!";
        local $/;
        <$g>;
    };

    foreach(1 .. 2) {
        my($out, $err) = perl($example);

        if($err =~ /Can't locate / # ' for poor editors
                or $err =~ /version \S+ required--this is only version /) {
            $err =~ s/ \(\@INC contains: [^\)]+\)//;
            diag("skip $example because: $err");
            next EXAMPLE;
        }

        is $out, $expect, $example . " ($_)";
        is $err, '', 'no errors';
    }
}

done_testing;
