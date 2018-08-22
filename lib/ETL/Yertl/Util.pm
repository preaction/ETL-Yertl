package ETL::Yertl::Util;
our $VERSION = '0.040';
# ABSTRACT: Utility functions for Yertl modules

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use ETL::Yertl;
use Exporter qw( import );
use Module::Runtime qw( use_module compose_module_name );

our @EXPORT_OK = qw(
    load_module firstidx
    docs_from_string
);

sub docs_from_string {
    my ( $format, $string );
    if ( @_ > 1 ) {
        $format = ETL::Yertl::Format->get( $_[0] );
        $string = $_[1];
    }
    else {
        $format = ETL::Yertl::Format->get_default;
        $string = $_[0];
    }
    my @docs = $format->read_buffer( \$string, 1 );
    return @docs;
}

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

=sub firstidx

    my $i = firstidx { ... } @array;

Return the index of the first item that matches the code block, or C<-1> if
none match

=cut

# This duplicates List::Util firstidx, but this is not included in Perl 5.10
sub firstidx(&@) {
    my $code = shift;
    for my $i ( 0 .. @_ ) {
        local $_ = $_[ $i ];
        return $i if $code->();
    }
    return -1;
}

1;
