package ETL::Yertl::Command::ygrok;
our $VERSION = '0.039';
# ABSTRACT: Parse lines of text into documents

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module docs_from_string );
use Getopt::Long qw( GetOptionsFromArray );
use Regexp::Common;
use File::HomeDir;
use Hash::Merge::Simple qw( merge );
use IO::Async::Loop;
use ETL::Yertl::Format;
use ETL::Yertl::FormatStream;

our %PATTERNS = (
    WORD => '\b\w+\b',
    DATA => '.*?',
    NUM => $RE{num}{real}."",   # stringify to allow YAML serialization
    INT => $RE{num}{int}."",    # stringify to allow YAML serialization
    VERSION => '\d+(?:[.]\d+)*',

    DATE => {
        MONTH => '\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\b',
        ISO8601 => '\d{4}-?\d{2}-?\d{2}[T ]\d{2}:?\d{2}:?\d{2}(?:Z|[+-]\d{4})',
        HTTP => '\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}',
        SYSLOG => '%{DATE.MONTH} +\d{1,2} \d{1,2}:\d{1,2}:\d{1,2}',
    },

    OS => {
        USER => '[a-zA-Z0-9._-]+',
        PROCNAME => '[\w._-]+',
    },

    NET => {
        HOSTNAME => join( "|", $RE{net}{IPv4}, $RE{net}{IPv6}, $RE{net}{domain}{-rfc1101} ),
        IPV6 => $RE{net}{IPv6}."",
        IPV4 => $RE{net}{IPv4}."",
    },

    URL => {
        PATH => '[^?#]*(?:\?[^#]*)?',
        # URL regex from URI.pm
        URL => '(?:[^:/?#]+:)?(?://[^/?#]*)?[^?#]*(?:\?[^#]*)?(?:#.*)?',
    },

    LOG => {
        HTTP_COMMON => join( " ",
            '%{NET.HOSTNAME:remote_addr}', '%{OS.USER:ident}', '%{OS.USER:user}',
            '\[%{DATE.HTTP:timestamp}]',
            '"%{WORD:method} %{URL.PATH:path} [^/]+/%{VERSION:http_version}"',
            '%{INT:status}', '(?<content_length>\d+|-)',
        ),
        HTTP_COMBINED => join( " ",
            '%{LOG.HTTP_COMMON}',
            '"%{URL:referer}"', '"%{DATA:user_agent}"',
        ),
        SYSLOG => join( "",
            '%{DATE.SYSLOG:timestamp} ',
            '(?:<%{INT:facility}.%{INT:priority}> )?',
            '%{NET.HOSTNAME:host} ',
            '%{OS.PROCNAME:program}(?:\[%{INT:pid}\])?: ',
            '%{DATA:text}',
        ),
    },

    POSIX => {
        LS => join( " +",
            '(?<mode>[bcdlsp-][rwxSsTt-]{9})',
            '%{INT:links}',
            '%{OS.USER:owner}',
            '%{OS.USER:group}',
            '%{INT:bytes}',
            '(?<modified>%{DATE.MONTH} +\d+ +\d+(?::\d+)?)',
            '%{DATA:name}',
        ),

        # -- Mac OSX
        #       TTY field starts with "tty"
        #       No STAT field
        # -- OpenBSD
        #       STAT field
        # -- RHEL 5
        #       tty can contain /
        #       Seconds time optional
        PS => join( " +",
            ' *%{INT:pid}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))?',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        ),

        # Mac OSX and OpenBSD are the same
        PSU => join ( " +",
            '%{OS.USER:user}',
            '%{INT:pid}',
            '%{NUM:cpu}',
            '%{NUM:mem}',
            '%{INT:vsz}',
            '%{INT:rss}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))?',
            '(?<started>[\w:]+)',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        ),

        # Max OSX and OpenBSD are the same
        PSX => join ( " +",
            ' *%{INT:pid}',
            '(?<tty>[\w?/]+)',
            '(?<status>(?:[\w+]+))',
            '(?<time>\d+:\d+(?:[:.]\d+)?)',
            '%{DATA:command}',
        ),
    },

    LINUX => {
        PROC => {
            UPTIME => '%{NUM:uptime}\s+%{NUM:idletime}',
            LOADAVG => '%{NUM:load1m}\s+%{NUM:load5m}\s+%{NUM:load15m}\s+%{INT:running}/%{INT:total}\s+%{INT:lastpid}',
        },
    },

);

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my @args = @_;
    GetOptionsFromArray( \@args, \%opt,
        'pattern',
        'loose',
    );

    # Manage patterns
    if ( $opt{pattern} ) {
        my ( $pattern_name, $pattern ) = @args;

        if ( $pattern ) {
            # Edit a pattern
            config_pattern( $pattern_name, $pattern );
        }
        else {
            my $patterns = $class->_all_patterns;

            if ( $pattern_name ) {
                # Show a single pattern
                my $pattern = $patterns;
                my @parts = split /[.]/, $pattern_name;
                for my $part ( @parts ) {
                    $pattern = $pattern->{ $part } ||= {};
                }

                if ( !ref $pattern ) {
                    say $pattern;
                }
                else {
                    my $out_fmt = load_module( format => 'default' )->new;
                    say $out_fmt->format( $pattern );
                }
            }
            else {
                # Show all patterns we know about
                my $out_fmt = load_module( format => 'default' )->new;
                say $out_fmt->format( $patterns );
            }
        }

        return 0;
    }

    # Grok incoming lines
    my ( $pattern, @files ) = @args;
    die "Must give a pattern\n" unless $pattern;

    my $re = $class->parse_pattern( $pattern );
    if ( !$opt{loose} ) {
        $re = qr{^$re$};
    }

    my $loop = IO::Async::Loop->new;

    my $out = ETL::Yertl::FormatStream->new_for_stdout(
        autoflush => 1,
    );
    $loop->add( $out );

    push @files, "-" unless @files;
    for my $file ( @files ) {

        # We're doing a similar behavior to <>, but manually for easier testing.
        my %args = (
            on_read => sub {
                my ( $self, $buffref, $eof ) = @_;
                while ( $$buffref =~ s/^(.*)\n// ) {
                    my $line = $1;
                    if ( $line =~ $re ) {
                        my $doc = { %+ };
                        $out->write( $doc );
                    }
                }
                return 0;
            },
            on_read_eof => sub { $loop->stop },
        );
        my $in;
        if ( $file eq '-' ) {
            $in = IO::Async::Stream->new_for_stdin( %args );
        }
        else {
            open my $fh, '<', $file or do {
                warn "Could not open file '$file' for reading: $!\n";
                next;
            };
            $in = IO::Async::Stream->new(
                read_handle => $fh,
                %args,
            );
        }
        $loop->add( $in );
        $loop->run;
    }

}

sub _all_patterns {
    my ( $class ) = @_;
    return merge( \%PATTERNS, config() );
}

sub _get_pattern {
    my ( $class, $pattern_name, $field_name ) = @_;

    #; say STDERR "_get_pattern( $pattern_name, $field_name )";

    # Handle nested patterns
    my @parts = split /[.]/, $pattern_name;
    my $pattern = $class->_all_patterns->{ shift @parts };
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

sub config {
    my $conf_file = path( File::HomeDir->my_home, '.yertl', 'ygrok.yml' );
    my $config = {};
    if ( $conf_file->exists ) {
        ( $config ) = docs_from_string( yaml => $conf_file->slurp );
    }
    return $config;
}

sub config_pattern {
    my ( $pattern_name, $pattern ) = @_;
    my $all_config = config();
    my $pattern_category = $all_config;
    my @parts = split /[.]/, $pattern_name;
    for my $part ( @parts[0..$#parts-1] ) {
        $pattern_category = $pattern_category->{ $part } ||= {};
    }

    if ( $pattern ) {
        my $conf_file = path( File::HomeDir->my_home, '.yertl', 'ygrok.yml' );
        if ( !$conf_file->exists ) {
            $conf_file->touchpath;
        }
        $pattern_category->{ $parts[-1] } = $pattern;
        my $yaml = load_module( format => 'yaml' )->new;
        $conf_file->spew( $yaml->format( $all_config ) );
        return;
    }
    return $pattern_category->{ $parts[-1] } || '';
}

1;
__END__
