package ETL::Yertl;
# ABSTRACT: ETL with a Shell

use strict;
use warnings;
use base 'Import::Base';

our @IMPORT_MODULES = (
    strict => [],
    warnings => [],
    feature => [qw( :5.10 )],
);

my @class_modules = (
    'Types::Standard' => [qw( :all )],
);

our %IMPORT_BUNDLES = (
    Test => [
        qw( Test::More Test::Deep Test::Exception Test::Differences ),
        FindBin => [ '$Bin' ],
        boolean => [':all'],
        'Path::Tiny' => [qw( path cwd )],
        'Dir::Self' => [qw( __DIR__ )],
    ],

    Class => [
        '<Moo::Lax',
        @class_modules,
    ],

    Role => [
        '<Moo::Role::Lax',
        @class_modules,
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

    ### In Perl...
    use ETL::Yertl;

    # XXX: To do: Perl API

=head1 DESCRIPTION

ETL::Yertl is an ETL for shells. It is designed to accept data from multiple formats
(CSV, JSON), manipulate them using simple tools, and then convert them to an output
format.

Yertl will have tools for:

=over 4

=item Extracting data from databases (MySQL, Postgres, MongoDB)

=item Loading data into databases

=item Extracting data from web services

=item Writing data to web services

=item Distributing data through messaging APIs (ZeroMQ)

=back

=head1 SEE ALSO

=head2 Yertl Tools

=over 4

=item L<yfrom>

=item L<yto>

=item L<ymask>

=item L<yq>

=back

=head2 Other Tools

Here are some other tools that can be used with Yertl

=over 4

=item jq

L<http://stedolan.github.io/jq/> A filter for JSON documents. The inspiration
for L<yq>.

=back

