package ETL::Yertl::Command::yts;
our $VERSION = '0.044';
# ABSTRACT: Read/Write time series data

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<yts>

=cut

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use Getopt::Long qw( GetOptionsFromArray :config pass_through );
use IO::Interactive qw( is_interactive );
use ETL::Yertl::Format;
use ETL::Yertl::FormatStream;
use IO::Async::Loop;

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my @args = @_;
    GetOptionsFromArray( \@args, \%opt,
        'start=s',
        'end=s',
        'short|s',
        'tags=s%',
    );
    #; use Data::Dumper;
    #; say Dumper \@args;
    #; say Dumper \%opt;

    my ( $db_spec, $metric ) = @args;

    die "Must give a database\n" unless $db_spec;

    my ( $db_type ) = $db_spec =~ m{^([^:]+):};

    my $db = load_module( adapter => $db_type )->new( $db_spec );

    # Write metrics
    if ( !is_interactive( \*STDIN ) ) {
        if ( $opt{short} ) {
            die "Must give a metric\n" unless $metric;
        }

        my $count = 0;
        my $loop = IO::Async::Loop->new;
        my $in = ETL::Yertl::FormatStream->new_for_stdin(
            on_doc => sub {
                my ( $self, $doc, $eof ) = @_;
                return unless $doc;
                #; use Data::Dumper
                #; say "Got doc: " . Dumper $doc;
                if ( $opt{short} ) {
                    my @docs;
                    for my $stamp ( sort keys %$doc ) {
                        push @docs, {
                            timestamp => $stamp,
                            metric => $metric,
                            value => $doc->{ $stamp },
                            ( $opt{tags} ? ( tags => $opt{tags} ) : () ),
                        };
                    }
                    #; use Data::Dumper;
                    #; print Dumper \@docs;
                    $db->write_ts( @docs );
                    $count += @docs;
                }
                else {
                    $doc->{metric} ||= $metric;
                    $doc->{tags} ||= $opt{tags} if $opt{tags};
                    $db->write_ts( $doc );
                    $count++;
                }
            },
            on_read_eof => sub { $loop->stop },
        );
        $loop->add( $in );
        $loop->run;
        #; say "Wrote $count points";
    }
    # Read metrics
    else {
        die "Must give a metric\n" unless $metric;
        my $out_fmt = ETL::Yertl::Format->get_default;
        my @points = $db->read_ts( {
            metric => $metric,
            tags => $opt{tags},
            start => $opt{start},
            end => $opt{end},
        } );
        if ( $opt{short} ) {
            my %ts = map { $_->{timestamp} => $_->{value} } @points;
            print $out_fmt->format( \%ts );
        }
        else {
            print $out_fmt->format( $_ ) for @points;
        }
    }

    return 0;
}

1;
__END__

