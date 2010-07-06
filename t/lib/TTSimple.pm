package t::lib::TTSimple;

use strict;
use constant USE_TT => scalar(grep { $_ eq '--tt' } @ARGV) || $ENV{USE_TT};
use Carp;

use parent qw(Exporter);
our @EXPORT = qw(render_str render_file);

use t::lib::Util;

my $tt;

if(USE_TT) {
    require Test::More;
    Test::More::note('use Template::Toolkit');

    require Template;
    $tt = Template->new(
        INCLUDE_PATH => path,
        ANYCASE      => 1,
    );
}
else {
    require Text::Xslate;
    require Text::Xslate::Syntax::TTerse;
    $tt = Text::Xslate->new(
            path      => [path],
            cache_dir =>  path,
            cache     =>  0,
            syntax    => 'TTerse',
            warn_handler => \&Carp::confess,
            die_handler  => \&Carp::confess,
    );
}

sub render_file {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process($in, $vars, \$out) or do {
            require Data::Dumper;
            croak Data::Dumper::Dumper($tt->error);
        };
        return $out;
    }
    else {
        return $tt->render($in, $vars);
    }
}

sub render_str {
    my($in, $vars) = @_;

    if(USE_TT) {
        my $out;
        $tt->process(\$in, $vars, \$out) or croak $tt->error, "($in)";
        return $out;
    }
    else {
        return $tt->render_string($in, $vars);
    }
}

