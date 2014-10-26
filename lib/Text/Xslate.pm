package Text::Xslate;
# The Xslate engine class
use 5.008_001;
use strict;
use warnings;

our $VERSION = '0.1033';

use Text::Xslate::Util qw($DEBUG
    mark_raw unmark_raw
    html_escape escaped_string
);

use Carp       ();
use File::Spec ();
use Exporter   ();

our @ISA = qw(Text::Xslate::Engine Exporter);

our @EXPORT_OK = qw(
    mark_raw unmark_raw
    escaped_string html_escape
);

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

package Text::Xslate::Engine;

use Text::Xslate::Util qw(
    $NUMBER $STRING $DEBUG
    literal_to_value
    import_from
);

BEGIN {
    my $dump_load_file = scalar($DEBUG =~ /\b dump=load_file \b/xms);
    *_DUMP_LOAD_FILE = sub(){ $dump_load_file };

    *_ST_MTIME = sub() { 9 }; # see perldoc -f stat

    my $cache_dir = File::Spec->catfile(
        $ENV{HOME} || File::Spec->tmpdir,
        '.xslate_cache');
    *_DEFAULT_CACHE_DIR = sub() { $cache_dir };
}

my $IDENT   = qr/(?: [a-zA-Z_][a-zA-Z0-9_\@]* )/xms;

# version-path-{compiler options}
my $XSLATE_MAGIC    = qq{.xslate "%s-%s-{%s}"\n};

my %compiler_option = (
    syntax      => undef,
    escape      => undef,
);

my %parser_option = (
    line_start => undef,
    tag_start  => undef,
    tag_end    => undef,
);

sub compiler_class() { 'Text::Xslate::Compiler' }

sub options { # overridable
    my($class) = @_;
    return {
        # name => default
        suffix      => '.tx',
        path        => ['.'],
        input_layer => ':utf8',
        cache       => 1,
        cache_dir   => _DEFAULT_CACHE_DIR,
        module      => undef,
        function    => undef,
        compiler    => $class->compiler_class,

        verbose      => 1,
        warn_handler => undef,
        die_handler  => undef,

        %compiler_option,
        %parser_option,
    };
}

sub new {
    my $class = shift;
    my %args  = (@_ == 1 ? %{$_[0]} : @_);

    my $options = $class->options;
    my $used    = 0;
    my $nargs   = scalar keys %args;
    while(my $key = each %{$options}) {
        if(exists $args{$key}) {
            $used++;
        }
        if(!defined($args{$key}) && defined($options->{$key})) {
            $args{$key} = $options->{$key};
        }
    }

    if($used != $nargs) {
        my @unknowns = grep { !exists $options->{$_} } keys %args;
        warnings::warnif(misc => "$class: Unknown option(s): " . join ' ', @unknowns);
    }

    my %funcs;
    if(defined $args{module}) {
        %funcs = import_from(@{$args{module}});
    }

    # function => { ... } overrides imported functions
    if(defined(my $funcs_ref = $args{function})) {
        while(my($name, $body) = each %{$funcs_ref}) {
            $funcs{$name} = $body;
        }
    }

    # the following functions are not overridable
    foreach my $builtin(qw(raw html dump)) {
        if(exists $funcs{$builtin}) {
            warnings::warnif(redefine =>
                "$class: You cannot redefine builtin function '$builtin',"
                . " because it is embeded in the engine");
        }
    }
    $funcs{raw}         = \&Text::Xslate::Util::mark_raw;
    $funcs{html}        = \&Text::Xslate::Util::html_escape;
    $funcs{mark_raw}    = \&Text::Xslate::Util::mark_raw;
    $funcs{unmark_raw}  = \&Text::Xslate::Util::unmark_raw;
    $funcs{dump}        = \&Text::Xslate::Util::p;

    $args{function} = \%funcs;

    if(!ref $args{path}) {
        $args{path} = [$args{path}];
    }

    # internal data
    $args{template} = {};

    return bless \%args, $class;
}

sub load_string { # for <input>
    my($self, $string) = @_;
    if(not defined $string) {
        $self->_error("LoadError: Template string is not given");
    }
    $self->{string} = $string;
    my $asm = $self->compile($string);
    $self->_assemble($asm, undef, undef, undef, undef);
    return $asm;
}

sub find_file {
    my($self, $file, $threshold_mtime) = @_;

    my $fullpath;
    my $cachepath;
    my $orig_mtime;
    my $cache_mtime;

    foreach my $p(@{$self->{path}}) {
        $fullpath = File::Spec->catfile($p, $file);
        defined($orig_mtime = (stat($fullpath))[_ST_MTIME])
            or next;

        # $file is found

        $cachepath = File::Spec->catfile($self->{cache_dir}, $file . 'c');

        if(-f $cachepath) {
            my $cmt = (stat(_))[_ST_MTIME]; # compiled

            # see also tx_load_template() in xs/Text-Xslate.xs
            if(($threshold_mtime || $cmt) >= $orig_mtime) {
                $cache_mtime = $cmt;
            }
        }

        last;
    }

    if(not defined $orig_mtime) {
        $self->_error("LoadError: Cannot find $file (path: @{$self->{path}})");
    }

    print STDOUT "  find_file: $fullpath\n" if _DUMP_LOAD_FILE;

    return {
        file        => $file,
        fullpath    => $fullpath,
        cachepath   => $cachepath,

        orig_mtime  => $orig_mtime,
        cache_mtime => $cache_mtime,
    };
}

sub load_file {
    my($self, $file, $mtime) = @_;

    print STDOUT "load_file($file)\n" if _DUMP_LOAD_FILE;

    if($file eq '<input>') { # simply reload it
        return $self->load_string($self->{string});
    }

    my $fi = $self->find_file($file, $mtime);

    my $asm = $self->_load_compiled($fi, $mtime) || $self->_load_source($fi, $mtime);

    # $cache_mtime is undef : uses caches without any checks
    # $cache_mtime > 0      : uses caches with mtime checks
    # $cache_mtime == 0     : doesn't use caches
    my $cache_mtime;
    if($self->{cache} < 2) {
        $cache_mtime = $fi->{cache_time} || 0;
    }

    $self->_assemble($asm, $file, $fi->{fullpath}, $fi->{cachepath}, $cache_mtime);
    return $asm;
}

sub _load_source {
    my($self, $fi) = @_;
    my $fullpath  = $fi->{fullpath};
    my $cachepath = $fi->{cachepath};

    my $source;
    {
        open my($in), '<' . $self->{input_layer}, $fullpath
            or $self->_error("LoadError: Cannot open $fullpath for reading: $!");
        local $/;
        $source = <$in>;
    }

    my $asm = $self->compile($source,
        file     => $fi->{file},
        fullpath => $fullpath,
    );

    if($self->{cache} >= 1) {
        my($volume, $dir) = File::Spec->splitpath($fi->{cachepath});
        my $cachedir      = File::Spec->catpath($volume, $dir, '');
        if(not -e $cachedir) {
            require File::Path;
            File::Path::mkpath($cachedir);
        }

        # use input_layer for caches
        if(open my($out), '>' . $self->{input_layer}, $cachepath) {
            $self->_save_compiled($out, $asm, $fullpath);

            if(!close $out) {
                 Carp::carp("Xslate: Cannot close $cachepath (ignored): $!");
                 unlink $cachepath;
            }
            else {
                $self->{cache_mtime} = ( stat $cachepath )[_ST_MTIME];
            }
        }
        else {
            Carp::carp("Xslate: Cannot open $cachepath for writing (ignored): $!");
        }
    }

    if(_DUMP_LOAD_FILE) {
        print STDERR "  _load_source: cache(",
            defined($self->{cache_mtime}) ? $self->{cache_mtime} : 'undef',
            ")\n";
    }

    return $asm;
}

sub _load_compiled {
    my($self, $fi, $threshold_mtime) = @_;

    $fi->{cache_mtime} = undef if $self->{cache} == 0;

    return undef if !$fi->{cache_mtime};

    $threshold_mtime ||= $fi->{cache_mtime};

    my $cachepath = $fi->{cachepath};

    open my($in), '<' . $self->{input_layer}, $cachepath
        or $self->_error("LoadError: Cannot open $cachepath for reading: $!");

    if(scalar(<$in>) ne $self->_magic($fi->{fullpath})) {
        # magic token is not matched
        close $in;
        unlink $cachepath
            or $self->_error("LoadError: Cannot unlink $cachepath: $!");
        return undef;
    }

    # parse assembly
    my @asm;
    while(defined(my $line = <$in>)) {
        next if $line =~ m{\A [ \t]* (?: \# | // )}xms; # comments
        chomp $line;

        my($name, $value, $line) = $line =~ m{
            \A
                [ \t]*
                ($IDENT)                        # an opname
                (?: [ \t]+ ($STRING|$NUMBER) )? # an operand   (optional)
                (?:\#($NUMBER))?                # line number  (optional)
                [^\n]*                          # any comments (optional)
            \z
        }xmsog or $self->_error("LoadError: Cannot parse assembly (line $.): $line");

        $value = literal_to_value($value);

        # checks the modified of dependencies
        if($name eq 'depend') {
            my $dep_mtime = (stat $value)[_ST_MTIME];
            if(!defined $dep_mtime) {
                $dep_mtime = '+inf'; # force reload
                Carp::carp("Xslate: failed to stat $value (ignored): $!");
            }
            if($dep_mtime > $threshold_mtime){
                close $in; # Win32 doesn't allow to remove opend files
                unlink $cachepath
                    or $self->_error("LoadError: Cannot unlink $cachepath: $!");

                printf "  _load_cache_compiled: %s(%s) is newer than %s(%s)\n",
                    $value,     scalar localtime($dep_mtime),
                    $cachepath, scalar localtime($threshold_mtime)
                        if _DUMP_LOAD_FILE;

                return undef;
            }
        }

        push @asm, [ $name, $value, $line ];
    }

    if(_DUMP_LOAD_FILE) {
        print STDERR "  _load_cache_compiled: cache(", $self->{cache_mtime}, ")\n";
    }

    return \@asm;
}

sub _save_compiled {
    my($self, $out, $asm, $fullpath) = @_;
    print $out $self->_magic($fullpath), $self->_compiler->as_assembly($asm);
    return;
}

sub _magic {
    my($self, $fullpath) = @_;

    my $opt = join(',',
        ref($self->{compiler}) || $self->{compiler},
        $self->_extract_options(\%compiler_option),
        $self->_extract_options(\%parser_option),
    );

    return sprintf $XSLATE_MAGIC,
        $VERSION, $fullpath, $opt;
}

sub _extract_options {
    my($self, $opt_ref) = @_;
    my @options;
    foreach my $name(sort keys %{$opt_ref}) {
        if(defined($self->{$name})) {
            push @options, $name => $self->{$name};
        }
    }
    return @options;
}

sub _compiler {
    my($self) = @_;
    my $compiler = $self->{compiler};

    if(!ref $compiler){
        $compiler ||= $self->compiler_class;
        require Any::Moose;
        Any::Moose::load_class($compiler);

        $compiler = $compiler->new(
            engine => $self,
            $self->_extract_options(\%compiler_option),
            parser_option => {
                $self->_extract_options(\%parser_option),
            },
        );

        $compiler->define_function(keys %{ $self->{function} });

        $self->{compiler} = $compiler;
    }

    return $compiler;
}

sub compile {
    my $self = shift;
    return $self->_compiler->compile(@_);
}

sub _error {
    shift;
    unshift @_, 'Xslate: ';
    goto &Carp::croak;
}

sub dump :method {
    goto &Text::Xslate::Util::p;
}

package Text::Xslate;
1;
__END__

=head1 NAME

Text::Xslate - High performance template engine

=head1 VERSION

This document describes Text::Xslate version 0.1033.

=head1 SYNOPSIS

    use Text::Xslate;
    use FindBin qw($Bin);

    my $tx = Text::Xslate->new(
        # the fillowing options are optional.
        path       => ['.'],
        cache_dir  => "$ENV{HOME}/.xslate_cache",
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
        : for $books -> $book {
            <li><: $book.title :></li>
        : } # for
        </ul>
    };

    print $tx->render_string($template, \%vars);

    # you can tell the engine that some strings are already escaped.
    use Text::Xslate qw(mark_raw);

    $vars{email} = mark_raw('gfx &lt;gfuji at cpan.org&gt;');
    # or if you don't want to pollute your namespace:
    $vars{email} = Text::Xslate::Type::Raw->new(
        'gfx &lt;gfuji at cpan.org&gt;',
    );

    # if you want Template-Toolkit syntx:
    $tx = Text::Xslate->new(syntax => 'TTerse');
    # ...

=head1 DESCRIPTION

B<Text::Xslate> (pronounced as /eks-leit/) is a high performance template engine
tuned for persistent applications.
This engine introduces the virtual machine paradigm. Templates are
compiled into xslate intermediate code, and then executed by the xslate
virtual machine.

The concept of Xslate is strongly influenced by Text::MicroTemplate
and Template-Toolkit, but the central philosophy of Xslate is different from them.
That is, the philosophy is B<sandboxing> that the template logic should
not have no access outside the template beyond your permission.

B<This software is under development>.
Version 0.1xxx is a developing stage, which may include radical changes.
Version 0.2xxx and more will be somewhat stable.

=head2 Features

=head3 High performance

Xslate has a virtual machine written in XS, which is highly optimized.
According to benchmarks, Xslate is much faster than other template
engines (Template-Toolkit, HTML::Template::Pro, Text::MicroTemplate, etc.).

There are benchmarks to compare template engines (see F<benchmark/> for details).

Here is a result of F<benchmark/others.pl> to compare various template engines.

    $ perl -Mblib benchmark/others.pl include 100
    Perl/5.10.1 i686-linux
    Text::Xslate/0.1025
    Text::MicroTemplate/0.11
    Template/2.22
    Text::ClearSilver/0.10.5.4
    HTML::Template::Pro/0.94
    1..4
    ok 1 - TT: Template-Toolkit
    ok 2 - MT: Text::MicroTemplate
    ok 3 - TCS: Text::ClearSilver
    ok 4 - HT: HTML::Template::Pro
    Benchmarks with 'include' (datasize=100)
             Rate     TT     MT    TCS     HT Xslate
    TT      313/s     --   -55%   -88%   -89%   -97%
    MT      697/s   123%     --   -72%   -75%   -93%
    TCS    2512/s   702%   260%     --    -9%   -74%
    HT     2759/s   781%   296%    10%     --   -71%
    Xslate 9489/s  2931%  1261%   278%   244%     --

You can see Xslate is 3 times faster than HTML::Template::Pro and Text::ClearSilver,
which are implemented in XS.

=head3 Template cascading

Xslate supports B<template cascading>, which allows you to extend
templates with block modifiers. It is like traditional template inclusion,
but is more powerful.

This mechanism is also called as template inheritance.

=head3 Syntax alternation

The Xslate virtual machine and the parser/compiler are completely separated
so that one can use alternative parsers.

For example, C<TTerse>, a Template-Toolkit compatible parser, is supported as a
completely different syntax parser.

=head1 INTERFACE

=head2 Methods

=head3 B<< Text::Xslate->new(%options) :XslateEngine >>

Creates a new xslate template engine with options.

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

=item C<< cache_dir => $dir // "$ENV{HOME}/.xslate_cache" >>

Specifies the directory used for caches. If C<$ENV{HOME}> doesn't exist,
C<< File::Spec->tmpdir >> will be used.

You B<should> specify this option on productions.

=item C<< function => \%functions >>

Specifies a function map. A function C<f> may be called as C<f($arg)> or C<$arg | f>.

There are a few builtin filters, but they are not overridable.

=item C<< module => [$module => ?\@import_args, ...] >>

Imports functions from I<$module>, which may be a function-based or bridge module.
Optional I<@import_args> are passed to C<import> as C<< $module->import(@import_args) >>.

For example:

    # for function-based modules
    my $tx = Text::Xslate->new(
        module => ['Time::Piece'],
    );
    print $tx->render_string(
        '<: localtime($x).strftime() :>',
        { x => time() },
    ); # => Wed, 09 Jun 2010 10:22:06 JST

    # for bridge modules
    my $tx = Text::Xslate->new(
        module => ['SomeModule::Bridge::Xslate'],
    );
    print $tx->render_string(
        '<: $x.some_method() :>',
        { x => time() },
    );

Because you can use function-based modules with the C<module> option, and
also can invoke any object methods in templates, Xslate doesn't require
specific namespaces for plugins.

=item C<< input_layer => $perliolayers // ':utf8' >>

Specifies PerlIO layers for reading templates.

=item C<< verbose => $level // 1 >>

Specifies the verbose level.

If C<< $level == 0 >>, all the possible errors will be ignored.

If C<< $level> >= 1 >> (default), trivial errors (e.g. to print nil) will be ignored,
but severe errors (e.g. for a method to throw the error) will be warned.

If C<< $level >= 2 >>, all the possible errors will be warned.

=item C<< suffix => $ext // '.tx' >>

Specify the template suffix, which is used for template cascading.

=item C<< syntax => $name // 'Kolon' >>

Specifies the template syntax you want to use.

I<$name> may be a short name (e.g. C<Kolon>), or a fully qualified name
(e.g. C<Text::Xslate::Syntax::Kolon>).

This option is passed to the compiler directly.

=item C<< escape => $mode // 'html' >>

Specifies the escape mode, which is automatically applied to template expressions.

Possible escape modes are B<html> and B<none>.

This option is passed to the compiler directly.

=item C<< line_start => $token // $parser_defined >>

Specify the token to start line code, which may be a string or a regular
expression.

This option is passed to the parser via the compiler.

=item C<< tag_start => $str // $parser_defined >>

Specify the token to start inline code, which may be a string or a
regular expression.

This option is passed to the parser via the compiler.

=item C<< line_start => $str // $parser_defined >>

Specify the token to end inline code, which may be a string or a
regular expression.

This option is passed to the parser via the compiler.


=back

=head3 B<< $tx->render($file, \%vars) :Str >>

Renders a template file with variables, and returns the result.
I<\%vars> is optional.

Note that I<$file> may be cached according to the cache level.

=head3 B<< $tx->render_string($string, \%vars) :Str >>

Renders a template string with variables, and returns the result.
I<\%vars> is optional.

Note that I<$string> is never cached so that this method is suitable for testing.

=head3 B<< $tx->load_file($file) :Void >>

Loads I<$file> for following C<render($file, \%vars)>. Compiles and saves it
as caches if needed.

This method can be used for pre-compiling template files.

=head2 Exportable functions

=head3 C<< mark_raw($str :Str) -> RawString >>

Marks I<$str> as raw, so that the content of I<$str> will be rendered as is,
so you have to escape these strings by yourself.

For example:

    my $tx   = Text::Xslate->new();
    my $tmpl = 'Mailaddress: <: $email :>';
    my %vars = (
        email => mark_raw('Foo &lt;foo@example.com&gt;'),
    );
    print $tx->render_string($tmpl, \%email);
    # => Mailaddress: Foo &lt;foo@example.com&gt;

This function is available in templates as the C<mark_raw> filter:

    <: $var | mark_raw :>
    <: $var | raw # alias :>

=head3 C<< unmark_raw($str :Str) -> Str >>

Clears the raw marker from I<$str>, so that the content of I<$str> will
be escaped before rendered.

This function is available in templates as the C<unmark_raw> filter:

    <: $var | unmark_raw :>

=head3 C<< html_escape($str :Str) -> RawString >>

Escapes html special characters in I<$str>, and returns a raw string (see above).
If I<$str> is already a raw string, it returns I<$str> as is.

You need not call this function explicitly, because all the values
will be escaped automatically.

This function is available in templates as the C<html> filter, but keep
in mind that it will do nothing if the argument is already escaped.
Consider C<< <: $var | unmark_raw | html :> >>, which forces to escape
the argument.

=head2 Application

C<xslate(1)> is provided as an interface to the Text::Xslate module, which
is used to process directory trees or evaluate one liners. For example:

    $ xslate -D name=value -o dest_path src_path

    $ xslate -e 'Hello, <: $ARGV[0] :> wolrd!' Xslate
    $ xslate -s TTerse -e 'Hello, [% ARGV.0 %] world!' TTerse

See L<xslate> for details.

=head1 TEMPLATE SYNTAX

There are several syntaxes you can use:

=over

=item Kolon

B<Kolon> is the default syntax, using C<< <: ... :> >> tags and
C<< : ... >> line code, which is explained in L<Text::Xslate::Syntax::Kolon>.

=item Metakolon

B<Metakolon> is the same as Kolon except for using C<< [% ... %] >> tags and
C<< %% ... >> line code, instead of C<< <: ... :> >> and C<< : ... >>.

=item TTerse

B<TTerse> is a syntax that is a subset of Template-Toolkit 2 (and partially TT3),
which is explained in L<Text::Xslate::Syntax::TTerse>.

=back

=head1 NOTES

There are common notes in Xslate.

=head2 Nil/undef handling

Note that nil (i.e. C<undef> in Perl) handling is different from Perl's.
Basically it does nothing, but C<< verbose => 2 >> will produce warnings on it.

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

Perl 5.8.1 or later.

If you have a C compiler, the XS backend will be used. Otherwise the pure Perl
backend is used.

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

Thanks to tokuhirom for the ideas, feature requests, encouragement, and bug finding.

Thanks to gardejo for the proposal to the name B<template cascading>.

Thanks to jjn1056 to the concept of template overlay (now implemented as C<cascade with ...>).

Thanks to makamaka for the contribution of Text::Xslate::PP.

=head1 AUTHOR

Fuji, Goro (gfx) E<lt>gfuji(at)cpan.orgE<gt>

Makamaka Hannyaharamitu (makamaka)

Maki, Daisuke (lestrrat)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Fuji, Goro (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
