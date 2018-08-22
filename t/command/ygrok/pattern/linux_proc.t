
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Command::ygrok;
my $SHARE_DIR = path( __DIR__, '..', '..', '..', 'share' );

sub test_ygrok {
    my ( $file, $pattern, $expect, $args ) = @_;

    $args ||= [];

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( @$args, $pattern, $file );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        my @docs = docs_from_string( $stdout );
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( @$args, $pattern );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        my @docs = docs_from_string( $stdout );
        cmp_deeply \@docs, $expect or diag explain \@docs;
    };
}

subtest '/proc/loadavg' => sub {
    my $file = $SHARE_DIR->child( lines => linux => 'proc_loadavg.txt' );
    my $pattern = '%{NUM:load1m}\s+%{NUM:load5m}\s+%{NUM:load15m}\s+%{INT:running}/%{INT:total}\s+%{INT:lastpid}';

    my @expect = (
        {
            load1m => '0.00',
            load5m => 0.01,
            load15m => 0.05,
            running => 1,
            total => 72,
            lastpid => 9774,
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{LINUX.PROC.LOADAVG}", \@expect )
};

subtest '/proc/uptime' => sub {
    my $file = $SHARE_DIR->child( lines => linux => 'proc_uptime.txt' );
    my $pattern = '%{NUM:uptime}\s+%{NUM:idletime}';

    my @expect = (
        {
            uptime => 4040.03,
            idletime => '3667.00',
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{LINUX.PROC.UPTIME}", \@expect )
};
done_testing;
