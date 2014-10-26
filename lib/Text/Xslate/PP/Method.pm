package Text::Xslate::PP::Method;
# xs/xslate-methods.xs in pure Perl
use strict;
use warnings;

use Text::Xslate::PP::State;
use Text::Xslate::PP::Type::Pair;

use Scalar::Util ();
use Carp         ();

our @CARP_NOT = qw(Text::Xslate::PP::Opcode Text::Xslate::PP::Booster);

our $_st;
*_st = *Text::Xslate::PP::_current_st;

sub _any_defined {
    my($any) = @_;
    return $_st->bad_arg('defined') if @_ != 1;
    return defined($any);
}

sub _array_size {
    my($array_ref) = @_;
    return $_st->bad_arg('size') if @_ != 1;
    return scalar @{$array_ref};
}

sub _array_join {
    my($array_ref, $sep) = @_;
    return $_st->bad_arg('join') if @_ != 2;
    return join $sep, @{$array_ref};
}

sub _array_reverse {
    my($array_ref) = @_;
    return $_st->bad_arg('reverse') if @_ != 1;
    return [ reverse @{$array_ref} ];
}

sub _array_sort {
    my($array_ref, $proc) = @_;
    return $_st->bad_arg('sort') if !(@_ == 1 or @_ == 2);
    if(@_ == 1) {
        return [ sort @{$array_ref} ];
    }
    else {
        return [ sort {
            push @{ $_st->{ SP } }, [ $a, $b ];
            Text::Xslate::PP::Opcode::tx_proccall($_st, $proc) + 0; # need to numify
        } @{$array_ref} ];
    }
}

sub _array_map {
    my($array_ref, $callback) = @_;
    return $_st->bad_arg('map') if @_ != 2;
    return [ map {
        push @{ $_st->{ SP } }, [ $_ ];
        Text::Xslate::PP::Opcode::tx_proccall($_st, $callback);
    } @{$array_ref} ];
}

sub _hash_size {
    my($hash_ref) = @_;
    return $_st->bad_arg('size') if @_ != 1;
    return scalar keys %{$hash_ref};
}

sub _hash_keys {
    my($hash_ref) = @_;
    return $_st->bad_arg('keys') if @_ != 1;
    return [sort { $a cmp $b } keys %{$hash_ref}];
}

sub _hash_values {
    my($hash_ref) = @_;
    return $_st->bad_arg('values') if @_ != 1;
    return [map { $hash_ref->{$_} } @{ _hash_keys($hash_ref) } ];
}

sub _hash_kv {
    my($hash_ref) = @_;
    $_st->bad_arg('kv') if @_ != 1;
    return [
        map { Text::Xslate::PP::Type::Pair->new(key => $_, value => $hash_ref->{$_}) }
        @{ _hash_keys($hash_ref) }
    ];
}

our %builtin_method = (
    'nil::defined'    => \&_any_defined,

    'scalar::defined' => \&_any_defined,

    'array::defined' => \&_any_defined,
    'array::size'    => \&_array_size,
    'array::join'    => \&_array_join,
    'array::reverse' => \&_array_reverse,
    'array::sort'    => \&_array_sort,
    'array::map'     => \&_array_map,

    'hash::defined'  => \&_any_defined,
    'hash::size'     => \&_hash_size,
    'hash::keys'     => \&_hash_keys,
    'hash::values'   => \&_hash_values,
    'hash::kv'       => \&_hash_kv,
);

sub tx_methodcall {
    my($st, $method) = @_;
    my($invocant, @args) = @{ pop @{ $st->{ SP } } };

    if(Scalar::Util::blessed($invocant)) {
        if($invocant->can($method)) {
            my $retval = eval { $invocant->$method(@args) };
            $st->error(undef, "%s", $@) if $@;
            return $retval;
        }
        $st->error(undef, "Undefined method %s called for %s",
            $method, $invocant);
        return undef;
    }

    my $type = ref($invocant) eq 'ARRAY' ? 'array::'
             : ref($invocant) eq 'HASH'  ? 'hash::'
             : defined($invocant)        ? 'scalar::'
             :                             'nil::';
    my $fq_name = $type . $method;

    if(my $body = $st->symbol->{$fq_name} || $builtin_method{$fq_name}){
        push @{ $st->{ SP } }, [ $invocant, @args ]; # re-pushmark
        return Text::Xslate::PP::Opcode::tx_proccall($st, $body);
    }
    if(!defined $invocant) {
        $st->warn(undef, "Use of nil to invoke method %s", $method);
        return undef;
    }

    $st->error(undef, "Undefined method %s called for %s",
        $method, $invocant);

    return undef;
}

1;
__END__

=head1 NAME

Text::Xslate::PP::Method - Text::Xslate builtin method call in pure Perl

=head1 DESCRIPTION

This module is used by Text::Xslate::PP internally.

=head1 SEE ALSO

L<Text::Xslate>

L<Text::Xslate::PP>

=cut
