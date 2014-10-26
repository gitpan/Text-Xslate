#!perl -w
use 5.010_000;
use strict;

use Text::Xslate;
use Text::MicroTemplate qw(build_mt);

use Benchmark qw(:all);
use Config; printf "Perl/%vd %s\n", $^V, $Config{archname};

foreach my $mod(qw(Text::Xslate Text::MicroTemplate)){
    say $mod, '/', $mod->VERSION;
}

my $n = shift(@ARGV) || 100;

my $x = Text::Xslate->new(
    string => "Hello, <?= \$lang ?> world!\n" x $n,
);

my $mt = build_mt("Hello, <?= \$_[0]->{lang} ?> world!\n" x $n);

my $subst_tmpl = qq{Hello, %lang% world!\n} x $n;

my $vars = {
    lang => 'Template',
};

$x->render($vars) eq $mt->($vars) or die $x->render($vars);

# suppose PSGI response body

cmpthese -1 => {
    xslate => sub {
        my $body = [$x->render($vars)];
        return;
    },
    mt => sub {
        my $body = [$mt->($vars)];
        return;
    },
    's///g' => sub {
        my $body = [$subst_tmpl];
        $body->[0] =~ s/%(\w+)%/$vars->{$1}/g;
        return;
    },
};

