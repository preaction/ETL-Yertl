
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

subtest 'ps -u' => sub {
    my $pattern = join( " +",
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
    );

    subtest 'Mac OSX' => sub {
        my $file = $SHARE_DIR->child( lines => macosx => 'ps-u.txt' ),
        my @expect = (
            {
                user => 'doug',
                pid => 617,
                cpu => '0.0',
                mem => 0.1,
                vsz => 2499620,
                rss => 5432,
                tty => 's001',
                status => 'Ss',
                started => 'Sat12PM',
                time => '0:01.92',
                command => '-zsh',
            },
            {
                user => 'doug',
                pid => 7201,
                cpu => '0.0',
                mem => 0.1,
                vsz => 2500644,
                rss => 7404,
                tty => 's004',
                status => 'Ss',
                started => 'Sat07PM',
                time => '0:05.37',
                command => '-zsh',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSU}", \@expect )
    };

    subtest 'OpenBSD' => sub {
        my $file = $SHARE_DIR->child( lines => openbsd => 'ps-u.txt' ),
        my @expect = (
            {
                user => 'doug',
                pid => 20045,
                cpu => '0.0',
                mem => '0.0',
                vsz => 680,
                rss => 492,
                tty => 'p0',
                status => 'Rs',
                started => '2:28PM',
                time => '0:00.01',
                command => '-ksh (ksh)',
            },
            {
                user => 'doug',
                pid => 27069,
                cpu => '0.0',
                mem => '0.0',
                vsz => 344,
                rss => 248,
                tty => 'p0',
                status => 'R+',
                started => '2:28PM',
                time => '0:00.00',
                command => 'ps -u',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSU}", \@expect )
    };

    subtest 'RHEL5' => sub {
        my $file = $SHARE_DIR->child( lines => rhel5 => 'ps-u.txt' ),
        my @expect = (
            {
                user => 'username', pid => 3075,        cpu => '0.0',
                mem => '0.0',       vsz => 89124,       rss => 3336,
                tty => 'pts/0',     status => 'Ss',     started => '18:29',
                time => '0:00',     command => '/usr2/local/bin/zsh',
            },
            {
                user => 'username', pid => 5248,        cpu => '0.0',
                mem => '0.0',       vsz => 69824,       rss => 1084,
                tty => 'pts/0',     status => 'R+',     started => '18:33',
                time => '0:00',     command => 'ps u',
            },
            {
                user => 'username', pid => 5249,        cpu => '0.0',
                mem => '0.0',       vsz => 58940,       rss => 576,
                tty => 'pts/0',     status => 'S+',     started => '18:33',
                time => '0:00',     command => 'head',
            },
            {
                user => 'username', pid => 20645,       cpu => '0.0',
                mem => '0.0',       vsz => 64892,       rss => 1436,
                tty => 'pts/1',     status => 'Ss+',    started => '2014',
                time => '0:00',     command => '/bin/ksh',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PSU}", \@expect )
    };

};

done_testing;
