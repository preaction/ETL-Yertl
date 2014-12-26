package ETL::Yertl::Command::yto;

use ETL::Yertl;
use Module::Runtime qw( use_module compose_module_name is_module_spec );
use ETL::Yertl::Format::yaml;

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

        my $buffer;
        my $scope = {};
        while ( my $line = <$fh> ) {
            # --- is the start of a new document
            if ( $buffer && $line =~ /^---/ ) {
                # Flush the previous document
                print $formatter->to( YAML::Load( $buffer ) );
                $buffer = '';
            }
            $buffer .= $line;
        }
        # Flush the buffer in the case of a single document with no ---
        if ( $buffer =~ /\S/ ) {
            #print STDERR "Buffer is: $buffer\n";
            print $formatter->to( YAML::Load( $buffer ) );
        }
    }
}

1;
__END__

=head1 SYNOPSIS

    ### On a shell...
    $ yto [-v] <format> [<file>...]
    $ yto [-h|--help|--version]

    ### In Perl...
    use ETL::Yertl;
    yto( '<format>', '<filename>', { verbose => 1 } );

=head1 DESCRIPTION

=head1 ARGUMENTS

=head1 OPTIONS

