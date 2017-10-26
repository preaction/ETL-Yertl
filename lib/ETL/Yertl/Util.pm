package ETL::Yertl::Util;
our $VERSION = '0.037';
# ABSTRACT: Utility functions for Yertl modules

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use ETL::Yertl;
use Exporter qw( import );
use Module::Runtime qw( use_module compose_module_name );

our @EXPORT_OK = qw(
    load_module pairs pairkeys firstidx
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

=sub pairs

    my @pairs = pairs @array;

Return an array of arrayrefs of pairs from the given even-sized array.

=cut

# This duplicates List::Util pair, but this is not included in Perl 5.10
sub pairs(@) {
    my ( @array ) = @_;
    my @pairs;
    while ( @array ) {
        push @pairs, [ shift( @array ), shift( @array ) ];
    }
    return @pairs;
}

=sub pairkeys

    my @keys = pairkeys @array;

Return the first item of every pair of items in an even-sized array.

=cut

# This duplicates List::Util pairkeys, but this is not included in Perl 5.10
sub pairkeys(@) {
    return map $_[$_], grep { $_ % 2 == 0 } 0..$#_;
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
