package ETL::Yertl::Command::ymask;
our $VERSION = '0.035';
# ABSTRACT: Filter documents through applying a mask

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use Data::Partial::Google;

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $mask, @files ) = @_;

    die "Must give a mask\n" unless $mask;

    my $filter = Data::Partial::Google->new( $mask );
    my $out_fmt = load_module( format => 'default' )->new;

    push @files, "-" unless @files;
    for my $file ( @files ) {
        # We're doing a similar behavior to <>, but manually for easier testing.
        my $fh;
        if ( $file eq '-' ) {
            # Use the existing STDIN so tests can fake it
            $fh = \*STDIN;
        }
        else {
            unless ( open $fh, '<', $file ) {
                warn "Could not open file '$file' for reading: $!\n";
                next;
            }
        }

        my $in_fmt = load_module( format => 'default' )->new( input => $fh );
        for my $doc ( $in_fmt->read ) {
            print $out_fmt->write( $filter->mask( $doc ) );
        }
    }
}

1;
__END__

