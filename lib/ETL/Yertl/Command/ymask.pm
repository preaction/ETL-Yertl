package ETL::Yertl::Command::ymask;

use ETL::Yertl;
use YAML;
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

        my $buffer;
        my $scope = {};
        while ( my $line = <$fh> ) {
            # --- is the start of a new document
            if ( $buffer && $line =~ /^---/ ) {
                # Flush the previous document
                print YAML::Dump( $filter->mask( YAML::Load( $buffer ) ) );
                $buffer = '';
            }
            $buffer .= $line;
        }
        # Flush the buffer in the case of a single document with no ---
        if ( $buffer =~ /\S/ ) {
            #print STDERR "Buffer is: $buffer\n";
            print YAML::Dump( $filter->mask( YAML::Load( $buffer ) ) );
        }
    }
}

1;
__END__

