package ETL::Yertl::Util;
our $VERSION = '0.031';
# ABSTRACT: Utility functions for Yertl modules

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use ETL::Yertl;
use Exporter qw( import );
use Module::Runtime qw( use_module compose_module_name );

our @EXPORT_OK = qw(
    load_module
);

=sub load_module

    $class = load_module( format => $format );
    $class = load_module( protocol => $proto );
    $class = load_module( database => $db );

Load a module of the given type with the given name. Throws an exception if the
module is not found or the module cannot be loaded.

This function should be used to load modules that the user requests. The error
messages are suitable for user consumption.

=cut

sub load_module {
    my ( $type, $name ) = @_;

    die "$type is required\n" unless $name;
    my $class = eval { compose_module_name( 'ETL::Yertl::' . ucfirst $type, $name ) };
    if ( $@ ) {
        die "Unknown $type '$name'\n";
    }

    eval {
        use_module( $class );
    };
    if ( $@ ) {
        if ( $@ =~ /^Can't locate \S+ in \@INC/ ) {
            die "Unknown $type '$name'\n";
        }
        die "Could not load $type '$name': $@";
    }

    return $class;
}

1;
