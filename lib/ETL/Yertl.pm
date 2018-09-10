package ETL::Yertl;
our $VERSION = '0.042';
# ABSTRACT: ETL with a Shell

use strict;
use warnings;
use 5.010;
use base 'Import::Base', 'Exporter';
use Carp qw( croak );
use Module::Runtime qw( use_module );
use ETL::Yertl::FormatStream;
use ETL::Yertl::Format;
use IO::Async::Loop;

our @EXPORT = qw( stdin stdout transform file yq );
our @EXPORT_OK = qw( loop );

sub loop;

sub import {
    $_[0]->export_to_level( 1, undef, @EXPORT );
    for my $i ( 1..$#_ ) {
        if ( grep { $_ eq ($_[ $i ] //= '') } @EXPORT_OK ) {
            $_[0]->export_to_level( 1, undef, $_[ $i ] );
            splice @_, $i, 1;
            redo;
        }
    }
    goto &Import::Base::import;
}

our @IMPORT_MODULES = (
    strict => [],
    warnings => [],
    feature => [qw( :5.10 )],
    'Path::Tiny' => [qw( path )],
);

our %IMPORT_BUNDLES = (
    Test => [
        qw( Test::More Test::Deep Test::Exception Test::Differences ),
        FindBin => [ '$Bin' ],
        boolean => [':all'],
        'Path::Tiny' => [qw( path cwd tempfile tempdir )],
        'Dir::Self' => [qw( __DIR__ )],
        'ETL::Yertl::Util' => [qw( docs_from_string )],
    ],
);

$ETL::Yertl::VERBOSE = $ENV{YERTL_VERBOSE} || 0;
sub yertl::diag {
    my ( $level, $text ) = @_;
    print STDERR "$text\n" if $ETL::Yertl::VERBOSE >= $level;
}

# format attribute takes simple string for named format object
sub stream(%) {
    my ( %args ) = @_;
    if ( $args{format} && !ref $args{format} ) {
        $args{format} = ETL::Yertl::Format->get( $args{format} );
    }
    my $stream = ETL::Yertl::FormatStream->new( %args );
    loop->add( $stream );
    return $stream;
}

=sub stdin

    my $stdin = stdin( %args );

Get a L<ETL::Yertl::FormatStream> object for standard input. C<%args> is a list
of key/value pairs passed to L<ETL::Yertl::FormatStream/new>. Useful keys are:

=over

=item format

Specify the format that standard input is. Defaults to C<yaml> or the value
of C<YERTL_FORMAT> (see L<ETL::Yertl::Format/get_default>.

=back

=cut

sub stdin(;%) {
    my ( %args ) = @_;
    $args{read_handle} = \*STDIN;
    return stream( %args );
}

=sub stdout

    my $stdout = stdout( %args );

Get a L<ETL::Yertl::FormatStream> object for standard output. C<%args> is a list
of key/value pairs passed to L<ETL::Yertl::FormatStream/new>. Useful keys are:

=over

=item format

Specify the format that standard input is. Defaults to C<yaml> or the value
of C<YERTL_FORMAT> (see L<ETL::Yertl::Format/get_default>.

=item autoflush

Immediately write documents to standard output to improve
responsiveness, instead of queuing them for later writes for efficiency.
This defaults to C<1> (on). Set it to C<0> to turn autoflush off.

=back

=cut

sub stdout(;%) {
    my ( %args ) = @_;
    $args{write_handle} = \*STDOUT;
    $args{autoflush} //= 1;
    return stream( %args );
}

=sub transform

    my $xform = transform( sub { ... } );
    my $xform = transform( 'Local::Transform::Class' => @args );

Create a new L<ETL::Yertl::Transform> object, passing in either a subref
to transform documents, or a class to instantiate and arguments to pass
to its constructor.

The subref will receive two arguments: The L<ETL::Yertl::Transform>
object and the document to transform. C<$_> will also be set to the
document to transform.  The subref should return the transformed
document (either a new document, or the existing document after being
modified).

If given a transform class, it should inherit from
L<ETL::Yertl::Transform>. The class will be loaded and an object
instantiated using the C<@args>.

=cut

sub transform($;%) {
    my ( $xform, @args ) = @_;
    my $obj;
    if ( !ref $xform ) {
        my $module = $xform;
        $obj = use_module( $module )->new( @args );
    }
    elsif ( ref $xform eq 'CODE' ) {
        $obj = ETL::Yertl::Transform->new(
            @args,
            transform_doc => $xform,
        );
    }
    loop->add( $obj );
    return $obj;
}

=sub file

    my $stream = file( $mode, $path, %args );

Create a L<ETL::Yertl::FormatStream> object for the given C<$path>.
C<$mode> should be one of C<< < >> for reading or C<< > >> for writing.
C<%args> are additional arguments to pass to the
L<ETL::Yertl::FormatStream> constructor. Useful keys are:

=over

=item format

Specify the format that standard input is. Defaults to C<yaml> or the value
of C<YERTL_FORMAT> (see L<ETL::Yertl::Format/get_default>.

=back

=cut

sub file( $$;% ) {
    my ( $mode, $name, %args ) = @_;
    # Detect whether to read_handle/write_handle via '<', '>'
    open my $fh, $mode, $name
        or croak sprintf q{Can't open file "%s": %s}, $name, $!;
    if ( $mode =~ /^</ ) {
        $args{read_handle} = $fh;
    }
    elsif ( $mode =~ /^>/ ) {
        $args{write_handle} = $fh;
    }
    else {
        croak sprintf q{Can't determine if mode "%s" is read or write}, $mode;
    }
    return stream( %args );
}

=sub yq

    my $xform = yq( $filter );

Create a L<ETL::Yertl::Transform::Yq> object with the given filter. See
L<yq/SYNTAX> for full filter syntax.

=cut

sub yq( $ ) {
    my ( $filter ) = @_;
    return transform(
        'ETL::Yertl::Transform::Yq',
        filter => $filter,
    );
}

=sub loop

    my $loop = loop();

Get the L<IO::Async::Loop> singleton. Use this to add other L<IO::Async> objects
to a larger program. This is not needed for simple Yertl streams, and is mostly
used internally.

This is not exported by default. You can import it using C<< use ETL::Yertl 'loop' >>.

=cut

sub loop() {
    state $loop = IO::Async::Loop->new;
    return $loop;
}

1;
__END__

=head1 SYNOPSIS

    ### On a shell...
    # Convert file to Yertl's format
    $ yfrom csv file.csv >work.yml
    $ yfrom json file.json >work.yml

    # Convert file to output format
    $ yto csv work.yml
    $ yto json work.yml

    # Parse HTTP logs into documents
    $ ygrok '%{LOG.HTTP_COMMON}' httpd.log

    # Read data from a database
    $ ysql db_name 'SELECT * FROM employee'

    # Write data to a database
    $ ysql db_name 'INSERT INTO employee ( id, name ) VALUES ( $.id, $.name )'

    ### In Perl...
    use ETL::Yertl;

    # Give everyone a 5% raise
    my $xform = file( '<', 'employees.yaml' )
              | transform( sub { $_->{salary} *= 1.05 } )
              >> stdout;
    $xform->run;

=head1 DESCRIPTION

ETL::Yertl is an ETL (L<Extract, Transform,
Load|https://en.wikipedia.org/wiki/Extract,_transform,_load>) for shells. It is
designed to accept data from multiple formats (CSV, JSON), manipulate them
using simple tools, and then convert them to an output format.

Yertl will have tools for:

=over 4

=item Extracting data from databases (MySQL, Postgres, MongoDB)

=item Loading data into databases

=item Extracting data from web services

=item Writing data to web services

=item Distributing data through messaging APIs (ZeroMQ)

=back

=head1 SEE ALSO

=over 4

=item L<http://preaction.me/yertl>

The Yertl home page.

=back

=head2 Yertl Tools

=over 4

=item L<yfrom>

Convert incoming data (CSV, JSON) to Yertl documents.

=item L<yto>

Convert Yertl documents into another format (CSV, JSON).

=item L<ygrok>

Parse lines of text into Yertl documents.

=item L<ysql>

Read/write documents from SQL databases.

=item L<yq>

A powerful mini-language for munging and filtering.

=back

=head2 Other Tools

Here are some other tools that can be used with Yertl

=over 4

=item L<recs (App::RecordStream)|App::RecordStream>

A set of tools for manipulating JSON (constrast with Yertl's YAML). For
interoperability, set the C<YERTL_FORMAT> environment variable to
C<"json">.

=item L<Catmandu|http://librecat.org>

A generic data processing toolkit. Convert data between multiple
formats, import/export into multiple databases, and manipulate data with
a mini-language.

This project is very much like Yertl, and more mature besides.

=item L<jq|http://stedolan.github.io/jq/>

A filter for JSON documents. The inspiration for L<yq>. For
interoperability, set the C<YERTL_FORMAT> environment variable to
C<"json">.

=item L<jt|App::jt>

JSON Transformer. Allows multiple ways of manipulating JSON, including
L<JSONPath|http://goessner.net/articles/JsonPath/>. For interoperability,
set the C<YERTL_FORMAT> environment variable to C<"json">.

=item L<pv (Pipe Viewer)|http://www.ivarch.com/programs/pv.shtml>

This tool helps examine how fast data is flowing through a shell
pipeline. If the size of the data is known, it can even provide
a progress bar and an ETA.

=item L<netcat (nc)|http://netcat.sourceforge.net>

Netcat allows simple streaming over a network. Using Netcat you can
start a Yertl pipeline on one machine and finish it on another machine.
For example, you could generate metrics on each client machine, and then
write them to a central machine to insert into a database on that
machine.

Netcat does not come with any security, so be careful (use firewalls).

=item L<socat|http://www.dest-unreach.org/socat/doc/socat.html>

Socat is a multi-purpose relay. It is similar to Netcat but with many
more features such as SSL and client verification. Socat has security,
so you can use this like Netcat in cases where you must accept data from
the Internet.

=item L<parallel (GNU Parallel)|https://www.gnu.org/software/parallel/>

GNU Parallel is a shell tool for executing jobs in parallel on one or more
computers. Parallel is very similar to C<xargs>, except it will execute
the commands on other computers.

=item L<distribution|https://github.com/wizzat/distribution>

This tool creates charts. Pipe into it from C<yq> to create simple
charts from your data.

=back

