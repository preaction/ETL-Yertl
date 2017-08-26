package ETL::Yertl::Command::yfrom;
our $VERSION = '0.033';
# ABSTRACT: Read documents from a format like JSON or CSV

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use Module::Runtime qw( use_module compose_module_name );

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $format, @files ) = @_;

    die "Must give a format\n" unless $format;
    my $formatter_class = load_module( format => $format );
    my $out_formatter = load_module( format => "default" )->new;

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

        my $in_formatter = $formatter_class->new( input => $fh, %opt );
        my @docs = $in_formatter->read;
        print $out_formatter->write( @docs );
    }
}

1;
__END__
