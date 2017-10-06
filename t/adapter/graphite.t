
=head1 DESCRIPTION

This test ensures that the Graphite adapter (L<ETL::Yertl::Adapter::graphite>)
is able to read/write time series data

=head1 SEE ALSO

L<yts>

=cut

use ETL::Yertl 'Test';
use IO::Async::Loop;
use IO::Async::Test qw( wait_for testing_loop );
use Mock::MonkeyPatch;
use Future;
use HTTP::Response;
use JSON::PP qw( encode_json );
use ETL::Yertl::Adapter::graphite;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

subtest 'constructor spec' => sub {
    subtest 'success' => sub {
        my $db = ETL::Yertl::Adapter::graphite->new( 'graphite://localhost:2003' );
        is $db->host, 'localhost', 'host is correct';
        is $db->write_port, 2003, 'write_port is correct';
        is $db->http_port, 2003, 'http_port is correct';
    };

    subtest 'port defaults to 8086' => sub {
        my $db = ETL::Yertl::Adapter::graphite->new( 'graphite://localhost' );
        is $db->host, 'localhost', 'host is correct';
        is $db->write_port, 2003, 'write_port is correct';
        is $db->http_port, 8080, 'http_port is correct';
    };

    subtest 'host is required' => sub {
        dies_ok { ETL::Yertl::Adapter::graphite->new( 'graphite://:8086' ) };
    };

};

subtest 'read ts' => sub {
    my $db = ETL::Yertl::Adapter::graphite->new(
        _loop => $loop,
        host => 'localhost',
    );

    my $content = encode_json(
        [{
          target => "cpu_load.1m",
          datapoints => [
            [1.0, 1311836008],
            [2.0, 1311836009],
            [3.0, 1311836010],
          ]
        }]
    );
    my $mock = Mock::MonkeyPatch->patch(
        'Net::Async::HTTP::GET' => sub {
            return Future->done(
                HTTP::Response->new(
                    200 => 'OK',
                    [
                        'Content-Length' => length $content,
                        'Content-Type' => 'text/plain',
                    ],
                    $content,
                ),
            );
        },
    );

    my @points = $db->read_ts( { metric => 'cpu_load.1m' } );
    cmp_deeply \@points, [
        {
            timestamp => '2011-07-28T06:53:28Z',
            metric => 'cpu_load.1m',
            value => 1.0,
        },
        {
            timestamp => '2011-07-28T06:53:29Z',
            metric => 'cpu_load.1m',
            value => 2.0,
        },
        {
            timestamp => '2011-07-28T06:53:30Z',
            metric => 'cpu_load.1m',
            value => 3.0,
        },
    ];

    ok $mock->called, 'mock GET called';
    my $args = $mock->method_arguments;
    my $url = URI->new( $args->[0] );
    is $url->host_port, 'localhost:8080', 'host/port is correct';
    cmp_deeply { $url->query_form }, {
        target => 'cpu_load.1m',
        format => 'json',
        noNullPoints => 'true',
    }, 'query params correct';
};

subtest 'write ts' => sub {
    my $empty = 0;
    my ( $reader, $writer ) = IO::Async::OS->pipepair;
    $_->blocking( 0 ) for $reader, $writer;

    my $stream = IO::Async::Stream->new(
        write_handle => $writer,
        on_outgoing_empty => sub { $empty++ },
    );
    $loop->add( $stream );

    my $db = ETL::Yertl::Adapter::graphite->new(
        _loop => $loop,
        host => 'localhost',
        write_client => $stream,
    );

    my @points = (
        {
            timestamp => '2017-01-01T00:00:00.000000000Z',
            metric => 'mydb.cpu_load.5m',
            value => 1.23,
        },
        {
            timestamp => '2017-01-01T00:05:00.000000000Z',
            metric => 'mydb.cpu_load.1m',
            value => 1.26,
        },
    );

    $db->write_ts( @points );
    wait_for { $empty };

    my @lines = (
        "mydb.cpu_load.5m 1.23 1483228800",
        "mydb.cpu_load.1m 1.26 1483229100",
        ""
    );
    my $buffer;
    $reader->sysread( $buffer, 8192 );
    is $buffer, join( "\n", @lines ), 'graphite plaintext protocol points correct';
};

done_testing;
