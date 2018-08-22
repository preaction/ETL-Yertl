
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

subtest 'ps -x' => sub {
    my $pattern = join( " +",
        ' *%{INT:pid}',
        '(?<tty>[\w?/]+)',
        '(?<status>(?:[\w+]+))',
        '(?<time>\d+:\d+(?:[:.]\d+)?)',
        '%{DATA:command}',
    );

    subtest 'Mac OSX' => sub {
        my $file = $SHARE_DIR->child( lines => macosx => 'ps-x.txt' ),
        my @expect = (
            {
                pid => 253,
                tty => '??',
                status => 'Ss',
                time => '0:00.07',
                command => '/System/Library/Frameworks/QTKit.framework/Versions/A/XPCServices/com.apple.qtkitserver.xpc/Contents/MacOS/com.apple.qtkitserver',
            },
            {
                pid => 298,
                tty => '??',
                status => 'S',
                time => '0:21.06',
                command => '/usr/libexec/UserEventAgent (Aqua)',
            },
            {
                pid => 300,
                tty => '??',
                status => 'S',
                time => '0:39.88',
                command => '/usr/sbin/distnoted agent',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSX}", \@expect )
    };

    subtest 'OpenBSD' => sub {
        my $file = $SHARE_DIR->child( lines => openbsd => 'ps-x.txt' ),
        my @expect = (
            {
                pid => 3713,
                tty => '??',
                status => 'S',
                time => '0:00.03',
                command => 'sshd: doug@ttyp0 (sshd)',
            },
            {
                pid => 20045,
                tty => 'p0',
                status => 'Ss',
                time => '0:00.02',
                command => '-ksh (ksh)',
            },
            {
                pid => 4243,
                tty => 'p0',
                status => 'R+',
                time => '0:00.00',
                command => 'ps -x',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSX}", \@expect )
    };

    subtest 'RHEL5' => sub {
        my $file = $SHARE_DIR->child( lines => rhel5 => 'ps-x.txt' ),
        my @expect = (
            {
                pid => 3075,
                tty => 'pts/0',
                status => 'Ss',
                time => '0:00',
                command => '/usr/local/bin/zsh',
            },
            {
                pid => 5345,
                tty => '?',
                status => 'Sl',
                time => '219:15',
                command => 'starman master',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSX}", \@expect )
    };
};

done_testing;
