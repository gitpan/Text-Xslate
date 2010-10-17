#line 1
package Module::Install::ExtendsMakeTest;

use 5.006_002;
use strict;
use warnings;
use vars qw($VERSION $TEST_DYNAMIC $TEST_TARGET $ORIG_TEST_VIA_HARNESS);
$VERSION = '0.02';

use base qw(Module::Install::Base);
use ExtUtils::MakeMaker ();
use Config;
use Carp qw(croak);

CHECK {
    $ORIG_TEST_VIA_HARNESS = MY->can('test_via_harness');
    no warnings 'redefine';
    *MY::test_via_harness = \&_test_via_harness;
}

$TEST_DYNAMIC = {
    env                => '',
    includes           => '',
    modules            => '',
    before_run_codes   => '',
    after_run_codes    => '',
    before_run_scripts => '',
    after_run_scripts  => '',
};

# override the default `make test`
sub replace_default_make_test {
    my ($self, %args) = @_;
    my %test = _build_command_parts(%args);
    $TEST_DYNAMIC = \%test;
}

# create a new test target
sub extends_make_test {
    my ($self, %args) = @_;
    my $target = $args{target} || croak 'target must be spesiced at extends_make_test()';
    my $alias  = $args{alias}  || '';

    my $test = _assemble(_build_command_parts(%args));

    $alias = $alias ? qq{\n$alias :: $target\n\n} : qq{\n};
    $self->postamble(
          $alias
        . qq{$target :: pure_all\n}
        . qq{\t} . $test
    );
}

sub _build_command_parts {
    my %args = @_;
    
    for my $key (qw/includes modules before_run_scripts after_run_scripts before_run_codes after_run_codes tests/) {
        $args{$key} ||= [];
        $args{$key} = [$args{$key}] unless ref $args{$key} eq 'ARRAY';
    }
    $args{env} ||= {};

    my %test;
    $test{includes} = @{$args{includes}} ? join '', map { qq|"-I$_" | } @{$args{includes}} : '';
    $test{modules}  = @{$args{modules}}  ? join '', map { qq|"-M$_" | } @{$args{modules}}  : '';
    $test{tests}    = @{$args{tests}}    ? join '', map { qq|"$_" |   } @{$args{tests}}    : '$(TEST_FILES)';
    for my $key (qw/before_run_scripts after_run_scripts/) {
        $test{$key} = @{$args{$key}} ? join '', map { qq|do '$_'; | } @{$args{$key}} : '';
    }
    for my $key (qw/before_run_codes after_run_codes/) {
        my $codes = join '', map { _build_funcall($_) } @{$args{$key}};
        $test{$key} = _quote($codes);
    }
    $test{env} = %{$args{env}} ? _quote(join '', map {
        my $key = _env_quote($_);
        my $val = _env_quote($args{env}->{$_});
        sprintf "\$ENV{q{%s}} = q{%s}; ", $key, $val
    } keys %{$args{env}}) : '';

    return %test;
}

my $bd;
sub _build_funcall {
    my($code) = @_;
    if(ref $code eq 'CODE') {
        $bd ||= do { require B::Deparse; B::Deparse->new() };
        $code = $bd->coderef2text($code);
    }
    return qq|sub { $code }->(); |;
}

sub _quote {
    my $code = shift;
    $code =~ s/\$/\\\$\$/g;
    $code =~ s/"/\\"/g;
    $code =~ s/\n/ /g;
    if ($^O eq 'MSWin32' and $Config{make} eq 'dmake') {
        $code =~ s/\\\$\$/\$\$/g;
        $code =~ s/{/{{/g;
        $code =~ s/}/}}/g;
    }
    return $code;
}

sub _env_quote {
    my $val = shift;
    $val =~ s/}/\\}/g;
    return $val;
}

sub _assemble {
    my %args = @_;
    my $command = MY->$ORIG_TEST_VIA_HARNESS($args{perl} || '$(FULLPERLRUN)', $args{tests});

    # inject includes and modules before the first switch
    $command =~ s/("- \S+? ")/$args{includes}$args{modules}$1/xms;

    # inject snipetts in the one-liner
    $command =~ s{("-e" \s+ ") (.+) (")}{
        join '', $1,
            $args{env},
            $args{before_run_scripts},
            $args{before_run_codes},
            $2,
            $args{after_run_scripts},
            $args{after_run_codes},
            $3,
    }xmse;
    return $command;
}

sub _test_via_harness {
    my($self, $perl, $tests) = @_;

    $TEST_DYNAMIC->{perl} = $perl;
    $TEST_DYNAMIC->{tests} ||= $tests;
    return _assemble(%$TEST_DYNAMIC);
}

1;
__END__

#line 340
