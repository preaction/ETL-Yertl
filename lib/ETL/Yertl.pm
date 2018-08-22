package ETL::Yertl;
our $VERSION = '0.039';
# ABSTRACT: ETL with a Shell

use strict;
use warnings;
use base 'Import::Base';

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

1;
__END__

=head1 SYNOPSIS

    ### On a shell...
    # Convert file to Yertl's format
    $ yfrom csv file.csv >work.yml
    $ yfrom json file.json >work.yml

    # Mask document
    $ ymask 'field/inner' work.yml >masked.yml

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

    # XXX: To do: Perl API

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

=item L<ymask>

Filter documents with a mask, letting only matching fields through.

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

=item L<jq|http://stedolan.github.io/jq/>

A filter for JSON documents. The inspiration for L<yq>. For
interoperability, set the C<YERTL_FORMAT> environment variable to
C<"json">.

=item L<jt|App::jt>

JSON Transformer. Allows multiple ways of manipulating JSON, including
L<JSONPath|http://goessner.net/articles/JsonPath/>. For interoperability,
set the C<YERTL_FORMAT> environment variable to C<"json">.

=back

