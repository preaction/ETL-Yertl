
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use Test::Lib;
use ETL::Yertl::Format::yaml;
use ETL::Yertl::Adapter::test;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/yts";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yts->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a database}, 'contains error message';
    };
};

subtest 'read' => sub {

    local @ETL::Yertl::Adapter::test::READ_TS = my @ts = (
        {
            timestamp => '2017-01-01 00:00:00',
            metric => 'cpu_load_1m',
            value => 1.23,
        },
        {
            timestamp => '2017-01-01 00:01:00',
            metric => 'cpu_load_1m',
            value => 1.26,
        },
    );

    subtest 'read metric' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            yts->main( 'test://localhost', 'cpu_load_1m' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@ts;
    };

    subtest 'read metric -- short' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            yts->main( 'test://localhost', 'cpu_load_1m', '--short' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], [ { map {; $_->{timestamp}, $_->{value} } @ts } ];
    };

    subtest 'read metric -- start/end' => sub {
        local @ETL::Yertl::Adapter::test::LAST_READ_TS_ARGS;
        my ( $stdout, $stderr, $exit ) = capture {
            yts->main( 'test://localhost', 'cpu_load_1m', '--start', '2017-01-01', '--end', '2017-01-02' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        cmp_deeply \@ETL::Yertl::Adapter::test::LAST_READ_TS_ARGS,
            [ {
                metric => 'cpu_load_1m',
                start => '2017-01-01',
                end => '2017-01-02',
                tags => undef,
            } ],
            'read_ts args correct'
                or diag explain \@ETL::Yertl::Adapter::test::LAST_READ_TS_ARGS;

        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@ts;
    };

    subtest 'error: no metric' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yts->main( 'test://localhost' ) };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a metric}, 'contains error message';
    };
};

subtest 'write' => sub {

    my @ts = (
        {
            timestamp => '2017-01-01T00:00:00',
            metric => 'cpu_load_1m',
            value => 1.23,
        },
        {
            timestamp => '2017-01-01T00:01:00',
            metric => 'cpu_load_1m',
            value => 1.26,
        },
    );

    subtest 'write metric' => sub {
        local @ETL::Yertl::Adapter::test::WRITE_TS = ();
        local *STDIN = $SHARE_DIR->child( 'command', 'yts', 'write.yml' )->openr;
        my ( $stdout, $stderr, $exit ) = capture {
            yts->main( 'test://localhost' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        ok !$stdout, 'nothing on stdout' or diag $stdout;

        cmp_deeply \@ETL::Yertl::Adapter::test::WRITE_TS, \@ts
            or diag explain \@ETL::Yertl::Adapter::test::WRITE_TS;
    };

    subtest 'write metric -- short' => sub {
        local @ETL::Yertl::Adapter::test::WRITE_TS = ();
        local *STDIN = $SHARE_DIR->child( 'command', 'yts', 'write-short.yml' )->openr;
        my ( $stdout, $stderr, $exit ) = capture {
            yts->main( 'test://localhost', '--short', 'cpu_load_1m' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply \@ETL::Yertl::Adapter::test::WRITE_TS, \@ts;
    };
};

done_testing;
