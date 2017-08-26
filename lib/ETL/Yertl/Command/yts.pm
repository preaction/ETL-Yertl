package ETL::Yertl::Command::yts;
our $VERSION = '0.033';
# ABSTRACT: Read/Write time series data

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<yts>

=cut

use ETL::Yertl;
use ETL::Yertl::Util qw( load_module );
use Getopt::Long qw( GetOptionsFromArray :config pass_through );

sub main {
    my $class = shift;

    my %opt;
    if ( ref $_[-1] eq 'HASH' ) {
        %opt = %{ pop @_ };
    }

    my @args = @_;
    GetOptionsFromArray( \@args, \%opt,
        'short|s',
        'tags=s%',
    );
    #; use Data::Dumper;
    #; say Dumper \@args;
    #; say Dumper \%opt;

    my ( $db_spec, $metric, $field ) = @args;

    die "Must give a database\n" unless $db_spec;
    $field ||= "value";

    my ( $db_type ) = $db_spec =~ m{^([^:]+):};

    my $db = load_module( adapter => $db_type )->new( $db_spec );

    # Write metrics
    if ( !-t STDIN && !-z *STDIN ) {
        if ( $opt{short} ) {
            die "Must give a metric\n" unless $metric;
        }

        my $in_fmt = load_module( format => 'default' )->new( input => \*STDIN );
        my $count = 0;

        while ( my @docs = $in_fmt->read ) {
            for my $doc ( @docs ) {
                #; use Data::Dumper
                #; say "Got doc: " . Dumper $doc;
                if ( $opt{short} ) {
                    my @docs;
                    for my $stamp ( sort keys %$doc ) {
                        push @docs, {
                            timestamp => $stamp,
                            metric => $metric,
                            value => $doc->{ $stamp },
                            field => $field,
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
                    $doc->{field} ||= $field;
                    $doc->{tags} ||= $opt{tags} if $opt{tags};
                    $db->write_ts( $doc );
                    $count++;
                }
            }
        }

        #; say "Wrote $count points";
    }
    # Read metrics
    else {
        die "Must give a metric\n" unless $metric;
        my $out_fmt = load_module( format => 'default' )->new;
        my @points = $db->read_ts( $metric, $field, $opt{tags} );
        if ( $opt{short} ) {
            my %ts = map { $_->{timestamp} => $_->{value} } @points;
            print $out_fmt->write( \%ts );
        }
        else {
            print $out_fmt->write( $_ ) for @points;
        }
    }

    return 0;
}

1;
__END__

