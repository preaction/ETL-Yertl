package ETL::Yertl::Command::ygrok;
# ABSTRACT: Parse lines of text into documents

use ETL::Yertl;
use ETL::Yertl::Format::yaml;

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my ( $pattern, @files ) = @_;
    die "Must give a pattern\n" unless $pattern;

    my $re = $class->parse_pattern( $pattern );

    my $out_formatter = ETL::Yertl::Format::yaml->new;
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
            #; say STDERR "$line =~ $re";
            if ( $line =~ $re ) {
                print $out_formatter->write( { %+ } );
            }
        }
    }
}

our %PATTERNS = (
    DATETIME => '\d{4}-?\d{2}-?\d{2}[T ]\d{2}:?\d{2}:?\d{2}(?:Z|[+-]\d{4})',
    WORD => '\b\w+\b',
    IPV4 => '\d{1,3}[.]\d{1,3}[.]\d{1,3}[.]\d{1,3}',
    DATA => '.*?',
);

sub parse_pattern {
    my ( $class, $pattern ) = @_;
    $pattern =~ s/\%\{([^:]+):([^:]+)\}/(?<$2>$PATTERNS{$1})/g;
    return qr{^$pattern$};
}

1;
__END__
