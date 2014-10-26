#!perl
# For rich environment, e.g. Persistent PSGI applications with XS

use strict;
use warnings;

use Text::Xslate;
use Text::MicroTemplate::Extended;
use Template;

use Getopt::Long;

use Test::More;
use Benchmark qw(:all);
use FindBin qw($Bin);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

GetOptions(
    'mst' => \my $try_mst,

    'size=i'     => \my $n,
    'template=s' => \my $tmpl,
    'help'       => \my $help,
);

die <<'HELP' if $help;
perl -Mblib benchmark/x-rich-env.pl [--size N] [--template NAME]

This is a general benchmark utility for rich environment,
assuming persisitent PSGI applications using XS modules.
See also benchmark/x-poor-env.pl.
HELP

require Text::Xslate;

$tmpl = 'include' if not defined $tmpl;
$n    = 100       if not defined $n;


my $has_tcs = eval q{ use Text::ClearSilver 0.10.5.4; 1 };
warn "Text::ClearSilver is not available ($@)\n" if $@;

my $has_mst = ($tmpl eq 'list' && $try_mst && eval q{ use MobaSiF::Template; 1 });
warn "MobaSiF::Template is not available ($@)\n" if $try_mst && $@;

my $has_htp = eval q{ use HTML::Template::Pro; 1 };
warn "HTML::Template::Pro is not available ($@)\n" if $@;

foreach my $mod(qw(
    Text::Xslate
    Text::MicroTemplate
    Text::MicroTemplate::Extended
    Template
    Text::ClearSilver
    MobaSiF::Template
    HTML::Template::Pro
)){
    print $mod, '/', $mod->VERSION, "\n" if $mod->VERSION;
}

my $path = "$Bin/template";

my $tx = Text::Xslate->new(
    path       => [$path],
    cache_dir  =>  '.xslate_cache',
    cache      => 2,
);
my $mt = Text::MicroTemplate::Extended->new(
    include_path => [$path],
    use_cache    => 2,
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

my $htp;
if($has_htp) {
    $htp = HTML::Template::Pro->new(
        path           => [$path],
        filename       => "$tmpl.ht",
        case_sensitive => 1,
    );
}

my $vars = {
    data => [ ({
            title    => "<FOO>",
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
    $tests++ if $has_htp;
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

    if($has_htp) {
        $htp->param($vars);
        $out = $htp->output();
        $out =~ s/\n+/\n/g;
        is $out, $expected, 'HTP: HTML::Template::Pro';
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
    $has_htp ? (
        HTP => sub {
            $htp->param($vars);
            my $body = $htp->output();
            return;
        },
    ) : (),
};

