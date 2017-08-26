package ETL::Yertl::Adapter::influxdb;
our $VERSION = '0.032';
# ABSTRACT: Adapter to read/write from InfluxDB time series database

use ETL::Yertl 'Class';
use Net::Async::HTTP;
use URI;
use JSON::MaybeXS qw( decode_json );
use List::Util qw( first );
use DateTime::Format::ISO8601;
use IO::Async::Loop;

has host => ( is => 'ro', required => 1 );
has port => ( is => 'ro', default => 8086 );
has db => ( is => 'ro', required => 1 );

has _loop => (
    is => 'ro',
    default => sub {
        IO::Async::Loop->new();
    },
);

has client => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my ( $self ) = @_;
        my $http = Net::Async::HTTP->new;
        $self->_loop->add( $http );
        return $http;
    },
);

has dt_fmt => (
    is => 'ro',
    lazy => 1,
    default => sub {
        DateTime::Format::ISO8601->new;
    },
);

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my %args;
    if ( @args == 1 ) {
        if ( $args[0] =~ m{://([^:]+)(?::([^/]+))?/(.+)} ) {
            @args{qw( host port db )} = ( $1, $2, $3 );
            delete $args{port} if !$args{port};
        }
    }
    else {
        %args = @args;
    }
    return \%args;
}

sub read_ts {
    my ( $self, $metric, $field, $tags ) = @_;
    $field ||= "value";

    my $q = sprintf 'SELECT "%s" FROM "%s"', $field, $metric;
    if ( $tags && keys %$tags ) {
        $q .= ' WHERE '
            . join " AND ",
                map { sprintf q{"%s"='%s'}, $_, $tags->{ $_ } }
                keys %$tags;
    }
    my $url = URI->new( sprintf 'http://%s:%s/query', $self->host, $self->port );
    $url->query_form( db => $self->db, q => $q );

    #; say "Fetching $url";
    my $res = $self->client->GET( $url )->get;

    #; say $res->decoded_content;
    if ( $res->is_error ) {
        die sprintf "Error fetching metric '%s': " . $res->decoded_content . "\n", $metric;
    }

    my $result = decode_json( $res->decoded_content );
    my @points;
    for my $series ( map @{ $_->{series} }, @{ $result->{results} } ) {
        my $time_i = first { $series->{columns}[$_] eq 'time' } 0..$#{ $series->{columns} };
        my $value_i = first { $series->{columns}[$_] eq $field } 0..$#{ $series->{columns} };

        push @points, map {
            +{
                metric => $series->{name},
                timestamp => $_->[ $time_i ],
                value => $_->[ $value_i ],
                ( $field ne 'value' ? ( field => $field ) : () ),
            }
        } @{ $series->{values} };
    }

    return @points;
}

sub write_ts {
    my ( $self, @points ) = @_;

    my @lines;
    for my $point ( @points ) {
        my $tags = '';
        if ( $point->{tags} ) {
            $tags = join ",", '', map { join "=", $_, $point->{tags}{$_} } keys %{ $point->{tags} };
        }

        my $ts = '';
        if ( $point->{timestamp} ) {
            $ts = " " . (
                $self->dt_fmt->parse_datetime( $point->{timestamp} )->hires_epoch * 10**9
            );
        }

        push @lines, sprintf '%s%s %s=%s%s',
            $point->{metric}, $tags, $point->{field} || "value",
            $point->{value}, $ts;
    }
    my $body = join "\n", @lines;

    my $url = URI->new( sprintf 'http://%s:%s/write?db=%s', $self->host, $self->port, $self->db );
    my $res = $self->client->POST( $url, $body, content_type => 'text/plain' )->get;
    if ( $res->is_error ) {
        my $result = decode_json( $res->decoded_content );
        die "Error writing metric '%s': $result->{error}\n";
    }

    return;
}

1;
