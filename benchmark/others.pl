#!perl
# templates: benchmark/template/list.*

use strict;
use warnings;

use Text::Xslate;
use Text::MicroTemplate::Extended;
use Template;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);

my $try_mst = grep { $_ eq '--mst' } @ARGV;

my $tmpl   = !Scalar::Util::looks_like_number($ARGV[0]) && shift(@ARGV);
   $tmpl ||= 'list';
my $n      = shift(@ARGV) || ($tmpl eq 'list' ? 100 : 10);

if(!($tmpl eq 'list' or $tmpl eq 'include')) {
    die "$0 [list | include] [n]\n";
}

use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

my $has_tcs = eval q{ use Text::ClearSilver 0.10.5.4; 1 };
warn "Text::CelarSilver is not available ($@)\n" if $@;

my $has_mst = $tmpl eq 'list' && $try_mst && eval q{ use MobaSiF::Template; 1 };
warn "MobaSif::Template is not available ($@)\n" if $@;

my $has_ht = eval q{ use HTML::Template::Pro; 1 };
warn "HTML::Template::Pro is not available ($@)\n" if $@;

foreach my $mod(qw(
    Text::Xslate Text::MicroTemplate Template
    Text::ClearSilver MobaSiF::Template HTML::Template::Pro
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  $path,
    cache      => 2,
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path => [$path],
    cache        => 2,
);
my $tt = Template->new(
    INCLUDE_PATH => [$path],
    COMPILE_EXT  => '.out',
);

my $tcs;
if($has_tcs) {
    $tcs = Text::ClearSilver->new(
        VarEscapeMode => 'html',
        load_path     => [$path],
    );
}

my $mst_in  = "$Bin/template/list.mst";
my $mst_bin = "$Bin/template/list.mst.out";
if($has_mst) {
    MobaSiF::Template::Compiler::compile($mst_in, $mst_bin);
}

my $ht;
if($has_ht) {
    $ht = HTML::Template::Pro->new(
        path           => [$path],
        filename       => "$tmpl.ht",
        case_sensitive => 1,
    );
}

my $vars = {
    data => [ ({
            title    => "FOO",
            author   => "BAR",
            abstract => "BAZ",
        }) x $n
   ],
};

{
    my $expected = $tx->render("$tmpl.tx", $vars);
    $expected =~ s/\n+/\n/g;

    my $tests = 2;
    $tests++ if $has_tcs;
    $tests++ if $has_mst;
    $tests++ if $has_ht;
    plan tests => $tests;

    $tt->process("$tmpl.tt", $vars, \my $out) or die $tt->error;
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'TT: Template-Toolkit';

    $out = $mt->render_file($tmpl, $vars);
    $out =~ s/\n+/\n/g;
    is $out, $expected, 'MT: Text::MicroTemplate';

    if($has_tcs) {
        $tcs->process("$tmpl.cs", $vars, \$out);
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'TCS: Text::ClearSilver';
    }

    if($has_mst) {
        $out = MobaSiF::Template::insert($mst_bin, $vars);
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'MST: MobaSiF::Template';
    }

    if($has_ht) {
        $ht->param($vars);
        $out = $ht->output();
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'HT: HTML::Template::Pro';
    }
}

print "Benchmarks with '$tmpl' (datasize=$n)\n";
cmpthese -1 => {
    Xslate => sub {
        my $body = $tx->render("$tmpl.tx", $vars);
        return;
    },
    MT => sub {
        my $body = $mt->render_file($tmpl, $vars);
        return;
    },
    TT => sub {
        my $body;
        $tt->process("$tmpl.tt", $vars, \$body) or die $tt->error;
        return;
    },

    $has_tcs ? (
        TCS => sub {
            my $body;
            $tcs->process("$tmpl.cs", $vars, \$body);
            return;
        },
    ) : (),
    $has_mst ? (
        MST => sub {
            my $body = MobaSiF::Template::insert($mst_bin, $vars);
            return;
        },
    ) : (),
    $has_ht ? (
        HT => sub {
            $ht->param($vars);
            my $body = $ht->output();
            return;
        },
    ) : (),
};

