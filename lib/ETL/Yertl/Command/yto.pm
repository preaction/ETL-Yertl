package ETL::Yertl::Command::yto;
our $VERSION = '0.034';
# ABSTRACT: Write documents to a format like JSON or CSV

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use Module::Runtime qw( use_module compose_module_name is_module_spec );

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $format, @files ) = @_;

    die "Must give a format\n" unless $format;
    my $out_fmt = load_module( format => $format )->new( %opt );

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
        print $out_fmt->write( $in_fmt->read );
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

