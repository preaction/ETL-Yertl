package ETL::Yertl::Command::yfrom;

use ETL::Yertl;
use YAML;
use Module::Runtime qw( use_module compose_module_name );

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $format, @files ) = @_;

    die "Must give a format\n" unless $format;
    my $formatter_class = compose_module_name( 'ETL::Yertl::Format', $format );
    eval {
        use_module( $formatter_class );
    };
    if ( $@ ) {
        if ( $@ =~ /^Can't locate \S+ in \@INC/ ) {
            die "Unknown format '$format'\n";
        }
        die "Could not load format '$format': $@";
    }

    my $formatter = $formatter_class->new( %opt );

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

        while ( my $line = <$fh> ) {
            my @docs = $formatter->from( $line );
            print YAML::Dump( @docs ) if @docs;
        }
    }
}

1;
__END__
