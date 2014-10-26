package Text::Xslate;
# The Xslate engine class
use 5.010_000;
use strict;
use warnings;

our $VERSION = '0.1018';

use parent qw(Exporter);
our @EXPORT_OK = qw(escaped_string html_escape);

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    literal_to_value
    import_from
);

use constant _DUMP_LOAD_FILE => scalar($DEBUG =~ /\b dump=load_file \b/xms);

if(!__PACKAGE__->can('render')) { # The backend (which is maybe PP.pm) has been loaded
    if($DEBUG !~ /\b pp \b/xms) {
        eval {
            require XSLoader;
            XSLoader::load(__PACKAGE__, $VERSION);
        };
        die $@ if $@ && $DEBUG =~ /\b xs \b/xms; # force XS
    }
    if(!__PACKAGE__->can('render')) { # failed to load XS, or force PP
        require 'Text/Xslate/PP.pm';
        Text::Xslate::PP->import(':backend');
    }
}

use Carp ();
use File::Spec;

use constant _ST_MTIME => 9; # see perldoc -f stat

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

my $XSLATE_MAGIC = qq{.xslate "%s-%s-%s"\n}; # version-syntax-escape

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    # options

    $args{suffix}       //= '.tx';
    $args{path}         //= [ '.' ];
    $args{input_layer}  //= ':utf8';
    $args{compiler}     //= 'Text::Xslate::Compiler';
    $args{syntax}       //= 'Kolon'; # passed directly to the compiler
    $args{escape}       //= 'html';
    $args{cache}        //= 1;
    $args{cache_dir}    //= File::Spec->tmpdir;

    my %funcs;
    if(defined $args{import}) {
        Carp::carp("'import' option has been renamed to 'module'"
            . " because of the confliction with Perl's import() method."
            . " Use 'module' instead");
        %funcs = import_from(@{$args{import}});
    }
    if(defined $args{module}) {
        %funcs = import_from(@{$args{module}});
    }

    # function => { ... } overrides imported functions
    if(my $funcs_ref = $args{function}) {
        while(my($name, $body) = each %{$funcs_ref}) {
            $funcs{$name} = $body;
        }
    }
    $args{function} = \%funcs;

    if(!ref $args{path}) {
        $args{path} = [$args{path}];
    }

    # internal data
    $args{template}       = {};

    my $self = bless \%args, $class;

    if(defined $args{file}) {
        Carp::carp('"file" option has been deprecated. Use render($file, \%vars) instead');
    }
    if(defined $args{string}) {
        Carp::carp('"string" option has been deprecated. Use render_string($string, \%vars) instead');
        $self->load_string($args{string});
    }

    return $self;
}

sub load_string { # for <input>
    my($self, $string) = @_;
    if(not defined $string) {
        $self->_error("LoadError: Template string is not given");
    }
    $self->{string} = $string;
    my $protocode = $self->_compiler->compile($string);
    $self->_initialize($protocode, undef, undef, undef, undef);
    return $protocode;
}

sub render_string {
    my($self, $string, $vars) = @_;

    local $self->{cache} = 0;
    local $self->{string};
    $self->load_string($string);
    return $self->render(undef, $vars);
}

sub find_file {
    my($self, $file, $mtime) = @_;

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;
    my $is_compiled;

    foreach my $p(@{$self->{path}}) {
        $fullpath = File::Spec->catfile($p, $file);
        $orig_mtime = (stat($fullpath))[_ST_MTIME] // next; # does not exist

        $cachepath = File::Spec->catfile($self->{cache_dir}, $file . 'c');

        if(-f $cachepath) {
            $cache_mtime = (stat(_))[_ST_MTIME]; # compiled

            # mtime indicates the threshold time.
            # see also tx_load_template() in xs/Text-Xslate.xs
            $is_compiled = (($mtime // $cache_mtime) >= $orig_mtime);
            last;
        }
        else {
            $is_compiled = 0;
        }

        last;
    }

    if(not defined $orig_mtime) {
        $self->_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    return {
        fullpath    => $fullpath,
        cachepath   => $cachepath,

        orig_mtime  => $orig_mtime,
        cache_mtime => $cache_mtime,

        is_compiled => $is_compiled,
    };
}


sub load_file {
    my($self, $file, $mtime) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;

    if($file eq '<input>') { # simply reload it
        return $self->load_string($self->{string});
    }

    my $f = $self->find_file($file, $mtime);

    my $fullpath    = $f->{fullpath};
    my $cachepath   = $f->{cachepath};
    my $is_compiled = $f->{is_compiled};

    if($self->{cache} == 0) {
        $is_compiled = 0;
    }

    print STDOUT "---> $fullpath ($is_compiled)\n" if _DUMP_LOAD_FILE;

    my $string;
    {
        my $to_read = $is_compiled ? $cachepath : $fullpath;
        open my($in), '<' . $self->{input_layer}, $to_read
            or $self->_error("LoadError: Cannot open $to_read for reading: $!");

        if($is_compiled && scalar(<$in>) ne $self->_magic) {
            # magic token is not matched
            close $in;
            unlink $cachepath
                or $self->_error("LoadError: Cannot unlink $cachepath: $!");
            goto &load_file; # retry
        }

        local $/;
        $string = <$in>;
    }

    my $protocode;
    if($is_compiled) {
        $protocode = $self->deserialize($string);

        # checks the mtime of dependencies
        foreach my $code(@{$protocode}) {
            if($code->[0] eq 'depend') {
                my $dep_mtime = (stat $code->[1])[_ST_MTIME];
                if(!defined $dep_mtime) {
                    $dep_mtime = '+inf'; # force reload
                    Carp::carp("Xslate: failed to stat $code->[1] (ignored): $!");
                }
                if($dep_mtime > ($mtime // $f->{cache_mtime})){
                    unlink $cachepath
                        or $self->_error("LoadError: Cannot unlink $cachepath: $!");
                    printf "---> %s(%s) is newer than %s(%s)\n",
                        $code->[1], scalar localtime($dep_mtime),
                        $cachepath, scalar localtime($mtime // $f->{cache_mtime})
                            if _DUMP_LOAD_FILE;
                    goto &load_file; # retry
                }
            }
        }
    }
    else {
        $protocode = $self->_compiler->compile($string,
            file     => $file,
            fullpath => $fullpath,
        );

        if($self->{cache}) {
            my($volume, $dir) = File::Spec->splitpath($cachepath);
            my $cachedir      = File::Spec->catpath($volume, $dir, '');
            if(not -e $cachedir) {
                require File::Path;
                File::Path::mkpath($cachedir);
            }
            open my($out), '>:raw:utf8', $cachepath
                or $self->_error("LoadError: Cannot open $cachepath for writing: $!");

            print $out $self->serialize($protocode);

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $cachepath;
            }
            else {
                $is_compiled = 1;
            }
        }
    }
    # if $mtime is undef, the runtime does not check freshness of caches.
    my $cache_mtime;
    if($self->{cache} < 2) {
        if($is_compiled) {
            $cache_mtime = $f->{cache_mtime} // ( stat $cachepath )[_ST_MTIME];
        }
        else {
            $cache_mtime = 0; # no compiled cache, always need to reload
        }
    }

    $self->_initialize($protocode, $file, $fullpath, $cachepath, $cache_mtime);
    return $protocode;
}

sub _magic {
    my($self) = @_;
    return sprintf $XSLATE_MAGIC,
        $VERSION,
        $self->{syntax},
        $self->{escape},
    ;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        require Any::Moose;
        Any::Moose::load_class($compiler);
        $compiler = $compiler->new(
            engine       => $self,
            syntax      => $self->{syntax},
            escape_mode => $self->{escape},
        );

        if(my $funcs = $self->{function}) {
            $compiler->define_function(keys %{$funcs});
        }

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub deserialize {
    my($self, $assembly) = @_;

    my @protocode;
    while($assembly =~ m{
            ^[ \t]*
                ($IDENT)                        # an opname
                (?: [ \t]+ ($STRING|$NUMBER) )? # an operand
                (?:\#($NUMBER))?                # line number
                [^\n]*                          # any comments
            \n}xmsog) {

        my $name  = $1;
        my $value = $2;
        my $line  = $3;

        push @protocode, [ $name, literal_to_value($value), $line ];
    }

    return \@protocode;
}

sub serialize {
    my($self, $protocode) = @_;
    return $self->_magic . $self->_compiler->as_assembly($protocode);
}

sub _error {
    shift;
    unshift @_, 'Xslate: ';
    goto &Carp::croak;
}

# utility functions
sub escaped_string;

# TODO: make it into XS
sub html_escape {
    my($s) = @_;
    return $s if ref($s) eq 'Text::Xslate::EscapedString';

    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g; # " for poor editors
    $s =~ s/'/&#39;/g;  # ' for poor editors

    return escaped_string($s);
}

sub dump :method {
    goto &Text::Xslate::Util::p;
}

1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.1018.

=head1 SYNOPSIS

    use Text::Xslate;
    use FindBin qw($Bin);

    my $tx = Text::Xslate->new(
        # the fillowing options are optional.
        path       => ['.'],
        cache_dir  => File::Spec->tmpdir,
        cache      => 1,
    );

    my %vars = (
        title => 'A list of books',
        books => [
            { title => 'Islands in the stream' },
            { title => 'Programming Perl'      },
            { title => 'River out of Eden'     },
            { title => 'Beautiful code'        },
        ],
    );

    # for files
    print $tx->render('hello.tx', \%vars);

    # for strings
    my $template = q{
        <h1><: $title :></h1>
        <ul>
        : for $books ->($book) {
            <li><: $book.title :></li>
        : } # for
        </ul>
    };

    print $tx->render_string($template, \%vars);

    # you can tell the engine that some strings are already escaped.
    use Text::Xslate qw(escaped_string);

    $vars{email} = escaped_string('gfx &lt;gfuji at cpan.org&gt;');
    # or
    $vars{email} = Text::Xslate::EscapedString->new(
        'gfx &lt;gfuji at cpan.org&gt;',
    ); # if you don't want to pollute your namespace.


    # if you want Template-Toolkit syntx:
    $tx = Text::Xslate->new(syntax => 'TTerse');
    # ...

=head1 DESCRIPTION

B<Text::Xslate> is a template engine tuned for persistent applications.
This engine introduces the virtual machine paradigm. That is, templates are
compiled into xslate intermediate code, and then executed by the xslate
virtual machine.

The philosophy for Xslate is B<sandboxing> that the template logic should
not have no access outside the template beyond your permission.

B<This software is under development>.
Version 0.1xxx is a developing stage, which may include radical changes.
Version 0.2xxx and more will be somewhat stable.

=head2 Features

=head3 High performance

Xslate has a virtual machine written in XS, which is highly optimized.
According to benchmarks, Xslate is B<2-10 times faster> than other template
engines (Template-Toolkit, HTML::Template::Pro, Text::MicroTemplate, etc.).

=head3 Template cascading

Xslate supports B<template cascading>, which allows you to extend
templates with block modifiers. It is like traditional template inclusion,
but is more powerful.

This mechanism is also called as template inheritance.

=head3 Syntax alternation

The Xslate virtual machine and the parser/compiler are completely separated
so that one can use alternative parsers.

For example, C<TTerse>, a Template-Toolkit-like parser, is supported as a
completely different syntax.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) :XslateEngine >>

Creates a new xslate template engine.

Possible options are:

=over

=item C<< path => \@path // ['.'] >>

Specifies the include paths.

=item C<< cache => $level // 1 >>

Sets the cache level.

If I<$level> == 1 (default), Xslate caches compiled templates on the disk, and
checks the freshness of the original templates every time.

If I<$level> E<gt>= 2, caches will be created but the freshness
will not be checked.

I<$level> == 0 creates no caches. It's provided for testing.

=item C<< cache_dir => $dir // File::Spec->tmpdir >>

Specifies the directory used for caches.

=item C<< function => \%functions >>

Specifies functions, which may be called as C<f($arg)> or C<$arg | f>.

=item C<< module => [$module => ?\@import_args, ...] >>

Imports functions from I<$module>. I<@import_args> is optional.

For example:

    my $tx = Text::Xslate->new(
        module => ['Data::Dumper'], # use Data::Dumper
    );
    print $tx->render_string(
        '<: Dumper($x) :>',
        { x => [42] },
    );
    # => $VAR = [42]

You can use function based modules with the C<module> option, and also can invoke
object methods in templates. Thus, Xslate doesn't require the namespaces for plugins.

=item C<< input_layer => $perliolayers // ':utf8' >>

Specifies PerlIO layers for reading templates.

=item C<< syntax => $name // 'Kolon' >>

Specifies the template syntax you want to use.

I<$name> may be a short name (moniker), or a fully qualified name.

=item C<< escape => $mode // 'html' >>

Specifies the escape mode, which is automatically applied to template expressions.

Possible escape modes are B<html> and B<none>.

=item C<< verbose => $level // 1 >>

Specifies the verbose level.

If C<< $level == 0 >>, all the possible errors will be ignored.

If C<< $level> >= 1 >> (default), trivial errors (e.g. to print nil) will be ignored,
but severe errors (e.g. for a method to throw the error) will be warned.

If C<< $level >= 2 >>, all the possible errors will be warned.

=back

=head3 B<< $tx->render($file, \%vars) :Str >>

Renders a template file with variables, and returns the result.
I<\%vars> can be omitted.

Note that I<$file> may be cached according to the cache level.

=head3 B<< $tx->render_string($string, \%vars) :Str >>

Renders a template string with variables, and returns the result.
I<\%vars> can be omitted.

Note that I<$string> is never cached so that this method is suitable for testing.

=head3 B<< $tx->load_file($file) :Void >>

Loads I<$file> for following C<render($file, \%vars)>. Compiles and saves it
as caches if needed.

This method can be used for pre-compiling template files.

=head2 Exportable functions

=head3 C<< escaped_string($str :Str) -> EscapedString >>

Marks I<$str> as escaped. Escaped strings will not be escaped by the template 
engine, so you have to escape these strings by yourself.

For example:

    my $tx   = Text::Xslate->new();
    my $tmpl = 'Mailaddress: <: $email :>';
    my %vars = (
        email => 'Foo &lt;foo@example.com&gt;',
    );
    print $tx->render_string($tmpl, \%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

=head3 C<< html_escape($str :Str) -> EscapedString >>

Escapes html special characters in I<$str>, and returns an escaped string (see above).

=head1 TEMPLATE SYNTAX

There are several syntaxes you can use:

=over

=item Kolon

B<Kolon> is the default syntax, using C<< <: ... :> >> tags and
C<< : ... >> line code, which is explained in L<Text::Xslate::Syntax::Kolon>.

=item Metakolon

B<Metakolon> is the same as Kolon except for using C<< [% ... %] >> tags and
C<< % ... >> line code, instead of C<< <: ... :> >> and C<< : ... >>.

=item TTerse

B<TTerse> is a syntax that is a subset of Template-Toolkit 2,
which is explained in L<Text::Xslate::Syntax::TTerse>.

=back

=head1 NOTES

There are common notes in the Xslate virtual machine.

=head2 Nil handling

Note that nil handling is different from Perl's.

=over

=item to print

Prints nothing.

=item to access fields.

Returns nil. That is, C<< nil.foo.bar.baz >> produces nil.

=item to invoke methods

Returns nil. That is, C<< nil.foo().bar().baz() >> produces nil.

=item to iterate

Dealt as an empty array.

=item equality

C<< $var == nil >> returns true if and only if I<$var> is nil.

=back

=head1 DEPENDENCIES

Perl 5.10.0 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT. Patches are welcome :)

=head1 SEE ALSO

Xslate template syntaxes:

L<Text::Xslate::Syntax::Kolon>

L<Text::Xslate::Syntax::Metakolon>

L<Text::Xslate::Syntax::TTerse>

Xslate command:

L<xlsate>

Other template modules:

L<Text::MicroTemplate>

L<Text::MicroTemplate::Extended>

L<Text::ClearSilver>

L<Template-Toolkit>

L<HTML::Template>

L<HTML::Template::Pro>

L<Template::Alloy>

L<Template::Sandbox>

Benchmarks:

L<Template::Benchmark>

=head1 ACKNOWLEDGEMENT

Thanks to lestrrat for the suggestion to the interface of C<render()> and
the contribution of App::Xslate.

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug-finding.

Thanks to gardejo for the proposal to the name B<template cascading>.

Thanks to jjn1056 to the concept of template overlay (now implemented as C<cascade with ...>).

Thanks to makamaka for the contribution of Text::Xslate::PP.

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji(at)cpan.orgE<gt>

Makamaka Hannyaharamitu

Maki, Daisuke (lestrrat)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
