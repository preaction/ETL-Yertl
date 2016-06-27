
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
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
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( @$args, $pattern );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;
    };
}

subtest 'ls -l' => sub {
    my $file = $SHARE_DIR->child( lines => 'ls-l.txt' );
    my $pattern = join( " +",
        '(?<mode>[bcdlsp-][rwxSsTt-]{9})',
        '%{INT:links}',
        '%{OS.USER:owner}',
        '%{OS.USER:group}',
        '%{INT:bytes}',
        '(?<modified>%{DATE.MONTH} +\d+ +\d+(?::\d+)?)',
        '%{DATA:name}',
    );

    my @expect = (
        {
            mode => 'drwxr-xr-x',
            links => 15,
            owner => 'doug',
            group => 'staff',
            bytes => 510,
            modified => 'Jan 28 19:37',
            name => 'ETL-Yertl-0.021',
        },
        {
            mode => '-rw-r--r--',
            links => 1,
            owner => 'doug',
            group => 'staff',
            bytes => 43666,
            modified => 'Jan 28 19:37',
            name => 'ETL-Yertl-0.021.tar.gz',
        },
        {
            mode => 'drwxr-xr-x',
            links => 9,
            owner => 'doug',
            group => 'staff',
            bytes => 306,
            modified => 'Feb  1 19:44',
            name => 'bin',
        },
        {
            mode => '-rw-r--r--',
            links => 1,
            owner => 'doug',
            group => 'staff',
            bytes => 3654,
            modified => 'Feb  1  2012',
            name => 'dist.ini',
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{POSIX.LS}", \@expect )
};

done_testing;
