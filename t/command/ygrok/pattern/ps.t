
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

subtest 'ps' => sub {
    my $pattern = join( " +",
        ' *%{INT:pid}',
        '(?<tty>[\w?/]+)',
        '(?<status>(?:[\w+]+))?',
        '(?<time>\d+:\d+(?:[:.]\d+)?)',
        '%{DATA:command}',
    );

    subtest 'Mac OSX' => sub {
        my $file = $SHARE_DIR->child( lines => macosx => 'ps.txt' ),
        my @expect = (
            {
                pid => 20045,
                tty => 'ttys000',
                time => '0:00.01',
                command => '-ksh (ksh)',
            },
            {
                pid => 2643,
                tty => 'ttys001',
                time => '0:00.01',
                command => 'ps',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PS}", \@expect )
    };

    subtest 'OpenBSD' => sub {
        my $file = $SHARE_DIR->child( lines => openbsd => 'ps.txt' ),
        my @expect = (
            {
                pid => 20045,
                tty => 'p0',
                status => 'Ss',
                time => '0:00.01',
                command => '-ksh (ksh)',
            },
            {
                pid => 2643,
                tty => 'p0',
                status => 'R+',
                time => '0:00.01',
                command => 'ps',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PS}", \@expect )
    };

    subtest 'RHEL5' => sub {
        my $file = $SHARE_DIR->child( lines => rhel5 => 'ps.txt' ),
        my @expect = (
            {
                pid => 3075,
                tty => 'pts/0',
                time => '00:00:00',
                command => 'zsh',
            },
            {
                pid => 5076,
                tty => 'pts/0',
                time => '00:00:00',
                command => 'ps',
            },
        );

        test_ygrok( $file, $pattern, \@expect );
        test_ygrok( $file, "%{POSIX.PS}", \@expect )
    };

};

done_testing;
