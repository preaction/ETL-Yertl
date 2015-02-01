package ETL::Yertl::Command::ygrok;
# ABSTRACT: Parse lines of text into documents

use ETL::Yertl;
use ETL::Yertl::Format::yaml;
use Regexp::Common;

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
            if ( $line =~ /^$re$/ ) {
                print $out_formatter->write( { %+ } );
            }
        }
    }
}

our %PATTERNS = (
    WORD => '\b\w+\b',
    DATA => '.*?',
    NUM => $RE{num}{real},
    INT => $RE{num}{int},

    DATETIME => {
        ISO8601 => '\d{4}-?\d{2}-?\d{2}[T ]\d{2}:?\d{2}:?\d{2}(?:Z|[+-]\d{4})',
        HTTP => '\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}',
    },

    OS => {
        USER => '[a-zA-Z0-9._-]+',
    },

    NET => {
        HOSTNAME => join( "|", $RE{net}{IPv4}, $RE{net}{IPv6}, $RE{net}{domain}{-rfc1101} ),
        IPV4 => '\d{1,3}[.]\d{1,3}[.]\d{1,3}[.]\d{1,3}',
    },

    URL => {
        PATH => '[^?#]*(?:\?[^#]*)?',
        # URL regex from URI.pm
        URL => '(?:[^:/?#]+:)?(?://[^/?#]*)?[^?#]*(?:\?[^#]*)?(?:#.*)?',
    },

    LOG => {
        HTTP_COMMON => join( " ",
            '%{NET.HOSTNAME:remote_addr}', '%{OS.USER:ident}', '%{OS.USER:user}',
            '\[%{DATETIME.HTTP:timestamp}]',
            '"%{WORD:method} %{URL.PATH:path} HTTP/%{NUM:http_version}"',
            '%{INT:status}', '%{INT:content_length}',
        ),
        HTTP_COMBINED => join( " ",
            '%{LOG.HTTP_COMMON}',
            '"%{URL:referer}"', '"%{DATA:user_agent}"',
        ),
    },

);

sub _get_pattern {
    my ( $class, $pattern_name, $field_name ) = @_;

    #; say STDERR "_get_pattern( $pattern_name, $field_name )";

    # Handle nested patterns
    my @parts = split /[.]/, $pattern_name;
    my $pattern = $PATTERNS{ shift @parts };
    for my $part ( @parts ) {
        if ( !$pattern->{ $part } ) {
            # warn "Could not find pattern $pattern_name for field $field_name\n";
            if ( $field_name ) {
                return "%{$pattern_name:$field_name}";
            }
            return "%{$pattern_name}";
        }

        $pattern = $pattern->{ $part };
    }

    # Handle the "default" pattern for a pattern group
    if ( ref $pattern eq 'HASH' ) {
        $pattern = $pattern->{ $parts[-1] || $pattern_name };
    }

    if ( $field_name ) {
        return "(?<$field_name>" . $class->parse_pattern( $pattern ) . ")";
    }
    return "(?:" . $class->parse_pattern( $pattern ) . ")";
}

sub parse_pattern {
    my ( $class, $pattern ) = @_;
    $pattern =~ s/\%\{([^:}]+)(?::([^:}]+))?\}/$class->_get_pattern( $1, $2 )/ge;
    #; say STDERR 'PATTERN: ' . $pattern;
    return $pattern;
}

1;
__END__
