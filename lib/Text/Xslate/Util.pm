package Text::Xslate::Util;
# utilities for internals, not for users
use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT_OK = qw(
    literal_to_value import_from
    p
    $STRING $NUMBER $DEBUG
);

use Carp ();

my $dquoted = qr/" (?: \\. | [^"\\] )* "/xms; # " for poor editors
my $squoted = qr/' (?: \\. | [^'\\] )* '/xms; # ' for poor editors
our $STRING  = qr/(?: $dquoted | $squoted )/xms;

our $NUMBER  = qr/ [+-]? (?:
        (?: [0-9][0-9_]* (?: \. [0-9_]+)? \b) # decimal
        |
        (?: 0 (?:
            (?: [0-7_]+ )        # octal
            |
            (?: x [0-9a-fA-F_]+) # hex
            |
            (?: b [01_]+ )       # binary
        )?)
    )/xms;

our $DEBUG;
$DEBUG //= $ENV{XSLATE} // '';

my %esc2char = (
    't' => "\t",
    'n' => "\n",
    'r' => "\r",
);

sub literal_to_value {
    my($value) = @_;
    return undef if not defined $value;

    if($value =~ s/"(.*)"/$1/xms){
        $value =~ s/\\(.)/$esc2char{$1} || $1/xmseg;
    }
    elsif($value =~ s/'(.*)'/$1/xms) {
        $value =~ s/\\(['\\])/$1/xmsg; # ' for poor editors
    }
    else { # number
        if($value =~ s/\A ([+-]?) (?= 0[0-7xb])//xms) {
            $value = ($1 eq '-' ? -1 : +1)
                * oct($value); # also grok hex and binary
        }
        else {
            $value =~ s/_//xmsg;
        }
    }

    return $value;
}

sub import_from {
    my $code = <<'T';
package
    Text::Xslate::Util::_import;
T

    for(my $i = 0; $i < @_; $i++) {
        $code .= "use $_[$i]";
        if(ref $_[$i+1]){
            $code .= sprintf ' qw(%s)', join ' ', @{$_[++$i]};
        }
        $code .= ";\n";
    }

    my $e = do {
        local $@;
        eval $code;
        $@;
    };
    Carp::confess("Xslate: Failed to import:\n" . $code . $e) if $e;

    require Any::Moose;
    if (! __PACKAGE__->can('_get_code_ref')) {
        *_get_code_ref = Any::Moose::moose_is_preferred() ?
            sub {
                my($package, $name) = @_;
                no strict 'refs';
                no warnings 'once';
                use warnings FATAL => 'uninitialized';
                return *{$package . '::' . $name}{CODE};
            } :
            *Mouse::Util::get_code_ref
        ;
    }

    my @funcs = map {
            my $c = _get_code_ref('Text::Xslate::Util::_import', $_);
            $c ? ($_ => $c) : ();
        } keys %Text::Xslate::Util::_import::;

    delete $Text::Xslate::Util::{'_import::'};

    return @funcs;
}

sub p { # for debugging
    my($self) = @_;
    require 'Data/Dumper.pm'; # we don't want to create its namespace
    my $dd = Data::Dumper->new([$self]);
    $dd->Indent(1);
    return $dd->Dump() if defined wantarray;
    print $dd->Dump();
}


1;
__END__

=head1 NAME

Text::Xslate::Util - A set of utilities for Xslate

=head1 DESCRIPTION

This module provides internal utilities.

=head1 SEE ALSO

L<Text::Xslate>

=cut
