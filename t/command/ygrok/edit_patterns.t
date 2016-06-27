
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
use ETL::Yertl::Command::ygrok;
my $SHARE_DIR = path( __DIR__, '..', '..', 'share' );

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

my $test_conf = sub {
    my ( $home, $args, $expect ) = @_;

    my ( $stdout, $stderr, $exit ) = capture {
        ETL::Yertl::Command::ygrok->main( @$args );
    };
    ok !$exit, 'nothing returned';
    ok !$stderr, 'nothing on stderr' or diag $stderr;

    my $yaml_config = ETL::Yertl::Format::yaml->new(
        input => $home->child( '.yertl', 'ygrok.yml' )->openr,
    );
    my ( $config ) = $yaml_config->read;
    cmp_deeply $config, $expect, 'config is correct'
        or diag explain $config;
};

subtest 'plain pattern' => sub {
    my $home = tempdir;
    local $ENV{HOME} = "$home";

    subtest 'add pattern' => $test_conf,
        $home,
        [ '--pattern', 'TEST', 'test::\S+' ],
        { TEST => 'test::\S+' }
        ;

    subtest 'use pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_plain.txt' );
        my $pattern = '%{INT:line} %{TEST:string}';
        my @expect = (
            {
                line => 1,
                string => 'test::this_is_a_test',
            },
            {
                line => 2,
                string => 'test::another_test',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };

    subtest 'edit pattern' => $test_conf,
        $home,
        [ '--pattern', 'TEST', '.+' ],
        { TEST => '.+' }
        ;

    subtest 'use edited pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_plain_edit.txt' );
        my $pattern = '%{INT:line} %{TEST:string}';
        my @expect = (
            {
                line => 1,
                string => 'test this_is_a_test',
            },
            {
                line => 2,
                string => 'test another_test',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };
};

subtest 'pattern category' => sub {
    my $home = tempdir;
    local $ENV{HOME} = "$home";

    subtest 'add pattern' => $test_conf,
        $home,
        [ '--pattern', 'TEST.FOO', '[1-9a-z]+' ],
        { TEST => { FOO => '[1-9a-z]+' } }
        ;

    subtest 'use pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_category.txt' );
        my $pattern = '%{INT:line} %{TEST.FOO:string}';
        my @expect = (
            {
                line => 1,
                string => 'fizz1buzz',
            },
            {
                line => 2,
                string => 'fizz5fizz15',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };

    subtest 'edit pattern' => $test_conf,
        $home,
        [ '--pattern', 'TEST.FOO', '[1-9a-z ]+' ],
        { TEST => { FOO => '[1-9a-z ]+' } }
        ;

    subtest 'use edited pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_category_edit.txt' );
        my $pattern = '%{INT:line} %{TEST.FOO:string}';
        my @expect = (
            {
                line => 1,
                string => 'fizz 1 buzz',
            },
            {
                line => 2,
                string => 'fizz 5 fizz 15',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };
};

subtest 'override built-in patterns' => sub {
    my $home = tempdir;
    local $ENV{HOME} = "$home";

    subtest 'add pattern' => $test_conf,
        $home,
        [ '--pattern', 'NET.HOSTNAME', '~[a-z][a-z0-9.]+' ],
        { NET => { HOSTNAME => '~[a-z][a-z0-9.]+' } }
        ;

    subtest 'use pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_override.txt' );
        my $pattern = '%{INT:line} %{NET.HOSTNAME:host}';
        my @expect = (
            {
                line => 1,
                host => '~www.example.com',
            },
            {
                line => 2,
                host => '~www4.example.net',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };

    subtest 'edit pattern' => $test_conf,
        $home,
        [ '--pattern', 'NET.HOSTNAME', '!![a-z][a-z0-9.]+' ],
        { NET => { HOSTNAME => '!![a-z][a-z0-9.]+' } }
        ;

    subtest 'use pattern' => sub {
        my $file = $SHARE_DIR->child( lines => 'custom_override_edit.txt' );
        my $pattern = '%{INT:line} %{NET.HOSTNAME:host}';
        my @expect = (
            {
                line => 1,
                host => '!!www.example.com',
            },
            {
                line => 2,
                host => '!!www4.example.net',
            },
        );
        test_ygrok( $file, $pattern, \@expect );
    };
};

subtest 'list patterns' => sub {
    my $home = tempdir;
    local $ENV{HOME} = "$home";

    subtest 'add pattern' => $test_conf,
        $home,
        [ '--pattern', 'NET.HOSTNAME', '~[a-z][a-z0-9.]+' ],
        { NET => { HOSTNAME => '~[a-z][a-z0-9.]+' } }
        ;

    subtest 'list a single pattern' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( '--pattern', 'WORD' );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        is $stdout, '\b\w+\b' . "\n", 'pattern is shown on stdout';

        ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( '--pattern', 'NET.HOSTNAME' );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        is $stdout, '~[a-z][a-z0-9.]+' . "\n", 'pattern is shown on stdout';
    };

    subtest 'list a category' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( '--pattern', 'NET' );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs,
            [
                {
                    %{ $ETL::Yertl::Command::ygrok::PATTERNS{ NET } },
                    HOSTNAME => '~[a-z][a-z0-9.]+',
                }
            ]
            or diag explain \@docs;
    };

    subtest 'list all patterns' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ETL::Yertl::Command::ygrok->main( '--pattern' );
        };
        ok !$exit, 'nothing returned';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs,
            [
                {
                    %ETL::Yertl::Command::ygrok::PATTERNS,
                    NET => {
                        %{ $ETL::Yertl::Command::ygrok::PATTERNS{ NET } },
                        HOSTNAME => '~[a-z][a-z0-9.]+',
                    },
                }
            ]
            or diag explain \@docs;;
    };

};

done_testing;
