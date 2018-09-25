
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

BEGIN {
    eval { require DBI; require DBD::SQLite; };
    if ( $@ ) {
        plan skip_all => 'missing DBI and/or DBD::SQLite';
    }
};

my $script = "$FindBin::Bin/../../bin/ysql";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ysql->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must specify a database!}, 'contains error message';
    };
};

subtest 'config' => sub {

    subtest 'read config' => sub {

        subtest 'by key' => sub {
            local $ENV{HOME} = $SHARE_DIR->child( 'command', 'ysql' )->stringify;

            subtest 'sqlite' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( '--config', 'test' );
                };
                ok !$stderr, 'nothing on stderr' or diag $stderr;
                is $exit, 0, 'success exit status';

                my ( $config ) = docs_from_string( yaml => $stdout );
                cmp_deeply
                    $config,
                    {
                        driver => 'SQLite',
                        database => 'test.db',
                    },
                    'reading config is correct'
                    or diag explain $config;
            };

            subtest 'mysql' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( '--config', 'dev' );
                };
                ok !$stderr, 'nothing on stderr' or diag $stderr;
                is $exit, 0, 'success exit status';

                my ( $config ) = docs_from_string( yaml => $stdout );
                cmp_deeply
                    $config,
                    {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'dev.example.com',
                        port => 4650,
                        user => 'preaction',
                        password => 'example',
                    },
                    'reading config is correct'
                    or diag explain $config;
            };

            subtest 'does not exist' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( '--config', 'DOES_NOT_EXIST' );
                };
                ok !$stdout, 'nothing on stdout' or diag $stdout;
                like $stderr, qr{ERROR: Database key 'DOES_NOT_EXIST' does not exist};
                isnt $exit, 0, 'error exit status';
            };

            subtest 'config was not altered' => sub {
                my $config_path = $SHARE_DIR->child( 'command', 'ysql', '.yertl', 'ysql.yml' );
                my ( $config ) = docs_from_string( yaml => $config_path->slurp );
                cmp_deeply
                    $config,
                    {
                        test => {
                            driver => 'SQLite',
                            database => 'test.db',
                        },

                        dev => {
                            driver => 'mysql',
                            database => 'foo',
                            host => 'dev.example.com',
                            port => 4650,
                            user => 'preaction',
                            password => 'example',
                        },

                        prod => {
                            driver => 'mysql',
                            database => 'foo',
                            host => 'example.com',
                            port => 4650,
                            user => 'produser',
                            password => 'production',
                        },

                    },
                    'config is correct'
                    or diag explain $config;
            };
        };

        subtest 'all keys' => sub {
            local $ENV{HOME} = $SHARE_DIR->child( 'command', 'ysql' )->stringify;

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( '--config' );
            };
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            is $exit, 0, 'success exit status';

            my ( $config ) = docs_from_string( yaml => $stdout );
            cmp_deeply
                $config,
                {
                    test => {
                        driver => 'SQLite',
                        database => 'test.db',
                    },

                    dev => {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'dev.example.com',
                        port => 4650,
                        user => 'preaction',
                        password => 'example',
                    },

                    prod => {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'example.com',
                        port => 4650,
                        user => 'produser',
                        password => 'production',
                    },

                },
                'config is correct'
                or diag explain $config;

            subtest 'config was not altered' => sub {
                my $config_path = $SHARE_DIR->child( 'command', 'ysql', '.yertl', 'ysql.yml' );
                my ( $config ) = docs_from_string( yaml => $config_path->slurp );
                cmp_deeply
                    $config,
                    {
                        test => {
                            driver => 'SQLite',
                            database => 'test.db',
                        },

                        dev => {
                            driver => 'mysql',
                            database => 'foo',
                            host => 'dev.example.com',
                            port => 4650,
                            user => 'preaction',
                            password => 'example',
                        },

                        prod => {
                            driver => 'mysql',
                            database => 'foo',
                            host => 'example.com',
                            port => 4650,
                            user => 'produser',
                            password => 'production',
                        },

                    },
                    'config is correct'
                    or diag explain $config;
            };
        };
    };

    subtest 'add/edit' => sub {

        my $conf_test = sub {
            my ( $home, $args, $expect, $opt ) = @_;
            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( '--config', 'test', @$args );
            };
            ok !$stdout, 'nothing on stdout' or diag $stdout;

            if ( $opt->{stderr} ) {
                like $stderr, qr{$opt->{stderr}}, 'stderr matches';
            }
            else {
                ok !$stderr, 'nothing on stderr' or diag $stderr;
            }
            is $exit, 0, 'success exit status';

            my $config_path = $home->child( '.yertl', 'ysql.yml' );
            my ( $config ) = docs_from_string( yaml => $config_path->slurp );
            cmp_deeply $config, { test => $expect }, 'config is correct'
                or diag explain $config;
        };

        subtest 'SQLite' => sub {

            subtest 'by DSN' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [ 'dbi:SQLite:test.db' ],
                    {
                        driver => 'SQLite',
                        database => 'test.db',
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [ 'dbi:SQLite:test2.db' ],
                    {
                        driver => 'SQLite',
                        database => 'test2.db',
                    };

            };

            subtest 'by DSN (with --dsn option)' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [ '--dsn', 'dbi:SQLite:test.db' ],
                    {
                        driver => 'SQLite',
                        database => 'test.db',
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [ '--dsn', 'dbi:SQLite:test2.db' ],
                    {
                        driver => 'SQLite',
                        database => 'test2.db',
                    };

            };

            subtest 'by options' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [
                        '--driver', 'SQLite',
                        '--db', 'test.db',
                    ],
                    {
                        driver => 'SQLite',
                        database => 'test.db',
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [
                        '--db', 'test2.db',
                    ],
                    {
                        driver => 'SQLite',
                        database => 'test2.db',
                    };

            };

            subtest 'warn on capitalization' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [ 'dbi:sqlite:test.db' ],
                    {
                        driver => 'sqlite',
                        database => 'test.db',
                    },
                    {
                        stderr => "Driver 'sqlite' does not exist. Did you mean: SQLite",
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [
                        '--driver', 'sqlite',
                        '--db', 'test2.db',
                    ],
                    {
                        driver => 'sqlite',
                        database => 'test2.db',
                    },
                    {
                        stderr => "Driver 'sqlite' does not exist. Did you mean: SQLite",
                    };

            };
        };

        subtest 'mysql' => sub {
            my $has_mysql = grep { /^mysql$/ } DBI->available_drivers;

            subtest 'by DSN' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [
                        'dbi:mysql:database=foo;host=localhost;port=4650',
                        '--user' => 'preaction',
                        '--password' => 'example',
                    ],
                    {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'localhost',
                        port => 4650,
                        user => 'preaction',
                        password => 'example',
                    },
                    {
                        stderr => $has_mysql ? '' : "Driver 'mysql' does not exist.",
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [
                        'dbi:mysql:database=foo;host=example.com',
                        '--user' => 'postaction',
                    ],
                    {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'example.com',
                        user => 'postaction',
                        password => 'example',
                    },
                    {
                        stderr => $has_mysql ? '' : "Driver 'mysql' does not exist.",
                    };

            };

            subtest 'by options' => sub {
                my $home = tempdir;
                local $ENV{HOME} = "$home";

                subtest 'add' => $conf_test,
                    $home,
                    [
                        '--driver', 'mysql',
                        '--db', 'foo',
                        '--host', 'localhost',
                        '--port', '4650',
                        '--user' => 'preaction',
                        '--password' => 'example',
                    ],
                    {
                        driver => 'mysql',
                        database => 'foo',
                        host => 'localhost',
                        port => 4650,
                        user => 'preaction',
                        password => 'example',
                    },
                    {
                        stderr => $has_mysql ? '' : "Driver 'mysql' does not exist.",
                    };

                subtest 'edit' => $conf_test,
                    $home,
                    [
                        '--db', 'test',
                        '--host', 'example.com',
                        '--password' => 'newpassword',
                    ],
                    {
                        driver => 'mysql',
                        database => 'test',
                        host => 'example.com',
                        port => 4650,
                        user => 'preaction',
                        password => 'newpassword',
                    },
                    {
                        stderr => $has_mysql ? '' : "Driver 'mysql' does not exist.",
                    };

            };
        };
    };
};

subtest 'drivers' => sub {
    my ( $stdout, $stderr, $exit ) = capture {
        ysql->main( '--drivers' );
    };
    is $exit, 0;
    ok !$stderr, 'nothing on stderr' or diag $stderr;
    my $ignore = join "|", qw( ExampleP Sponge File );
    for my $driver ( grep { !/^(?:$ignore)$/ } DBI->available_drivers ) {
        like $stdout, qr{$driver}, 'output contains driver: ' . $driver;
    }
};

subtest 'query' => sub {

    my $setup = sub {
        my $home = tempdir;

        my $conf = {
            testdb => {
                driver => 'SQLite',
                database => $home->child( 'test.db' )->stringify,
            },
        };
        my $conf_file = $home->child( '.yertl', 'ysql.yml' );
        my $yaml = ETL::Yertl::Format::yaml->new;
        $conf_file->touchpath->spew( $yaml->format( $conf ) );

        my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $home->child( 'test.db' ) );
        $dbh->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR, paygrade VARCHAR )' );
        my @people = (
            [ 1, 'Hazel Murphy', 'hank@example.com', 'E5' ],
            [ 2, 'Quentin Quinn', 'quinn@example.com', 'D1' ],
        );
        for my $person ( @people ) {
            $dbh->do( 'INSERT INTO person ( id, name, email, paygrade ) VALUES ( ?, ?, ?, ? )', {}, @$person );
        }

        return ( $home, $dbh );
    };

    subtest 'basic query' => sub {
        my ( $home ) = $setup->();
        local $ENV{HOME} = "$home";

        my ( $stdout, $stderr, $exit ) = capture {
            ysql->main( 'testdb', 'SELECT * FROM person' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        cmp_deeply [ docs_from_string( $stdout ) ], bag(
            {
                id => 1,
                name => 'Hazel Murphy',
                email => 'hank@example.com',
                paygrade => 'E5',
            },
            {
                id => 2,
                name => 'Quentin Quinn',
                email => 'quinn@example.com',
                paygrade => 'D1',
            },
        );

    };

    subtest 'sql helper options' => sub {
        subtest '--select' => sub {
            my ( $home ) = $setup->();
            local $ENV{HOME} = "$home";

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', '--select', 'person' );
            };
            is $exit, 0;
            ok !$stderr, 'nothing on stderr' or diag $stderr;

            cmp_deeply [ docs_from_string( $stdout ) ], bag(
                {
                    id => 1,
                    name => 'Hazel Murphy',
                    email => 'hank@example.com',
                    paygrade => 'E5',
                },
                {
                    id => 2,
                    name => 'Quentin Quinn',
                    email => 'quinn@example.com',
                    paygrade => 'D1',
                },
            );

            subtest '--where' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', '--select', 'person', '--where', 'id >= 2' );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;

                cmp_deeply [ docs_from_string( $stdout ) ], bag(
                    {
                        id => 2,
                        name => 'Quentin Quinn',
                        email => 'quinn@example.com',
                        paygrade => 'D1',
                    },
                );
            };

            subtest '--sort/--order' => sub {

                subtest '--sort with DESC' => sub {
                    my ( $stdout, $stderr, $exit ) = capture {
                        ysql->main( 'testdb', '--select', 'person', '--sort', 'id DESC' );
                    };
                    is $exit, 0;
                    ok !$stderr, 'nothing on stderr' or diag $stderr;

                    cmp_deeply [ docs_from_string( $stdout ) ], [
                        {
                            id => 2,
                            name => 'Quentin Quinn',
                            email => 'quinn@example.com',
                            paygrade => 'D1',
                        },
                        {
                            id => 1,
                            name => 'Hazel Murphy',
                            email => 'hank@example.com',
                            paygrade => 'E5',
                        },
                    ];
                };

                subtest '--order ASC by default' => sub {
                    my ( $stdout, $stderr, $exit ) = capture {
                        ysql->main( 'testdb', '--select', 'person', '--order', 'paygrade' );
                    };
                    is $exit, 0;
                    ok !$stderr, 'nothing on stderr' or diag $stderr;

                    cmp_deeply [ docs_from_string( $stdout ) ], [
                        {
                            id => 2,
                            name => 'Quentin Quinn',
                            email => 'quinn@example.com',
                            paygrade => 'D1',
                        },
                        {
                            id => 1,
                            name => 'Hazel Murphy',
                            email => 'hank@example.com',
                            paygrade => 'E5',
                        },
                    ];
                };

            };
        };

        subtest '--count' => sub {
            my ( $home ) = $setup->();
            local $ENV{HOME} = "$home";

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', '--count', 'person' );
            };
            is $exit, 0;
            ok !$stderr, 'nothing on stderr' or diag $stderr;

            cmp_deeply [ docs_from_string( $stdout ) ], bag(
                {
                    value => 2,
                },
            );

            subtest '--where' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', '--count', 'person', '--where', 'id >= 2' );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;

                cmp_deeply [ docs_from_string( $stdout ) ], bag(
                    {
                        value => 1,
                    },
                );
            };
        };

        subtest '--insert' => sub {
            my $home = tempdir;
            local $ENV{HOME} = "$home";

            my $conf = {
                testdb => {
                    driver => 'SQLite',
                    database => $home->child( 'test.db' )->stringify,
                },
            };
            my $conf_file = $home->child( '.yertl', 'ysql.yml' );
            my $yaml = ETL::Yertl::Format::yaml->new;
            $conf_file->touchpath->spew( $yaml->format( $conf ) );

            my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $home->child( 'test.db' ) );
            $dbh->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
            local *STDIN = $SHARE_DIR->child( 'command', 'ysql', 'write.yml' )->openr;

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', '--insert', 'person' );
            };
            is $exit, 0;
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            ok !$stdout, 'nothing on stdout' or diag $stdout;

            cmp_deeply
                $dbh->selectall_arrayref( 'SELECT id,name,email FROM person' ),
                bag(
                    [ 1, 'Hazel Murphy', 'hank@example.com' ],
                    [ 2, 'Quentin Quinn', 'quinn@example.com' ],
                );
        };

        subtest '--delete' => sub {
            my ( $home, $dbh ) = $setup->();
            local $ENV{HOME} = "$home";

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', '--delete', 'person' );
            };
            is $exit, 0;
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            ok !$stdout, 'nothing on stdout' or diag $stdout;

            cmp_deeply
                $dbh->selectall_arrayref( 'SELECT id,name,email FROM person' ),
                [];

            subtest '--where' => sub {
                my ( $home, $dbh ) = $setup->();
                local $ENV{HOME} = "$home";

                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', '--delete', 'person', '--where', 'id >= 2' );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;
                ok !$stdout, 'nothing on stdout' or diag $stdout;

                cmp_deeply
                    $dbh->selectall_arrayref( 'SELECT id,name,email FROM person' ),
                    bag(
                        [ 1, 'Hazel Murphy', 'hank@example.com' ],
                    );
            };

        };
    };

    subtest 'saved queries' => sub {
        subtest 'without placeholders' => sub {
            my ( $home ) = $setup->();
            local $ENV{HOME} = "$home";

            subtest 'save the query' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', '--save', 'testquery',
                        'SELECT * FROM person',
                    );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;
                ok !$stdout, 'nothing on stdout, query is not run' or diag $stdout;

                my $conf_file = $home->child( '.yertl', 'ysql.yml' );
                my ( $config ) = docs_from_string( $conf_file->slurp );
                cmp_deeply $config, {
                    testdb => {
                        driver => 'SQLite',
                        database => $home->child( 'test.db' )->stringify,
                        query => {
                            testquery => 'SELECT * FROM person',
                        },
                    },
                }, 'config is in the db' or diag explain $config;
            };

            subtest 'run the saved query' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', 'testquery' );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;

                cmp_deeply [ docs_from_string( $stdout ) ], bag(
                    {
                        id => 1,
                        name => 'Hazel Murphy',
                        email => 'hank@example.com',
                        paygrade => 'E5',
                    },
                    {
                        id => 2,
                        name => 'Quentin Quinn',
                        email => 'quinn@example.com',
                        paygrade => 'D1',
                    },
                );

            };
        };

        subtest 'with placeholders' => sub {
            my ( $home ) = $setup->();
            local $ENV{HOME} = "$home";

            subtest 'save the query' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', '--save', 'testquery',
                        'SELECT * FROM person WHERE email=?',
                    );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;
                ok !$stdout, 'nothing on stdout, query is not run' or diag $stdout;

                my $conf_file = $home->child( '.yertl', 'ysql.yml' );
                my ( $config ) = docs_from_string( $conf_file->slurp );
                cmp_deeply $config, {
                    testdb => {
                        driver => 'SQLite',
                        database => $home->child( 'test.db' )->stringify,
                        query => {
                            testquery => 'SELECT * FROM person WHERE email=?',
                        },
                    },
                }, 'config is in the db' or diag explain $config;
            };

            subtest 'run the saved query' => sub {
                my ( $stdout, $stderr, $exit ) = capture {
                    ysql->main( 'testdb', 'testquery', 'hank@example.com' );
                };
                is $exit, 0;
                ok !$stderr, 'nothing on stderr' or diag $stderr;

                cmp_deeply [ docs_from_string( $stdout ) ], bag(
                    {
                        id => 1,
                        name => 'Hazel Murphy',
                        email => 'hank@example.com',
                        paygrade => 'E5',
                    },
                );

            };
        };
    };

    subtest 'basic write' => sub {
        my $home = tempdir;
        local $ENV{HOME} = "$home";

        my $conf = {
            testdb => {
                driver => 'SQLite',
                database => $home->child( 'test.db' )->stringify,
            },
        };
        my $conf_file = $home->child( '.yertl', 'ysql.yml' );
        my $yaml = ETL::Yertl::Format::yaml->new;
        $conf_file->touchpath->spew( $yaml->format( $conf ) );

        my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $home->child( 'test.db' ) );
        $dbh->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
        local *STDIN = $SHARE_DIR->child( 'command', 'ysql', 'write.yml' )->openr;

        my ( $stdout, $stderr, $exit ) = capture {
            ysql->main( 'testdb',
                'INSERT INTO person (id, name, email) VALUES ($.id, $.name, $.email)',
            );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        ok !$stdout, 'nothing on stdout' or diag $stdout;

        cmp_deeply
            $dbh->selectall_arrayref( 'SELECT id,name,email FROM person' ),
            bag(
                [ 1, 'Hazel Murphy', 'hank@example.com' ],
                [ 2, 'Quentin Quinn', 'quinn@example.com' ],
            );
    };

    subtest 'interpolation' => sub {

        subtest 'deep data structure' => sub {
            my $home = tempdir;
            local $ENV{HOME} = "$home";

            my $conf = {
                testdb => {
                    driver => 'SQLite',
                    database => $home->child( 'test.db' )->stringify,
                },
            };
            my $conf_file = $home->child( '.yertl', 'ysql.yml' );
            my $yaml = ETL::Yertl::Format::yaml->new;
            $conf_file->touchpath->spew( $yaml->format( $conf ) );

            my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $home->child( 'test.db' ) );
            $dbh->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
            local *STDIN = $SHARE_DIR->child( 'command', 'ysql', 'deep.yml' )->openr;

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb',
                    'INSERT INTO person (id, name, email) VALUES ($.id, $.profile.name, $.email)',
                );
            };
            is $exit, 0;
            ok !$stderr, 'nothing on stderr' or diag $stderr;
            ok !$stdout, 'nothing on stdout' or diag $stdout;

            cmp_deeply
                $dbh->selectall_arrayref( 'SELECT id,name,email FROM person' ),
                bag(
                    [ 1, 'Hazel Murphy', 'hank@example.com' ],
                    [ 2, 'Quentin Quinn', 'quinn@example.com' ],
                );

        };
    };

    subtest 'error handling' => sub {
        my ( $home ) = $setup->();
        local $ENV{HOME} = "$home";

        subtest 'error in connect' => sub {
            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( '--dsn', 'dbi:SQLite:dbname=' . $home->child( 'MISSINGDIR', 'test.db' ), 'SELECT * FROM person' );
            };
            isnt $exit, 0, 'error happened';
            ok !$stdout, 'nothing on stdout' or diag $stdout;
            like $stderr, qr{ERROR: Could not connect to database "dbi:SQLite:dbname=[^"]+": unable to open database file};
            unlike $stderr, qr{Usage:}, "we don't need usage info";
        };

        subtest 'SQL error in prepare' => sub {
            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', 'SELECT FROM person' );
            };
            isnt $exit, 0, 'error happened';
            ok !$stdout, 'nothing on stdout' or diag $stdout;
            like $stderr, qr{ERROR: SQL error in prepare: near "FROM": syntax error};
            like $stderr, qr{\QQuery: SELECT FROM person}, 'stderr contains query';
            unlike $stderr, qr{Usage:}, "we don't need usage info";
        };

        subtest 'SQL error in execute' => sub {
            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb', 'SELECT * FROM person WHERE id=?', 1, "foo" );
            };
            isnt $exit, 0, 'error happened';
            ok !$stdout, 'nothing on stdout' or diag $stdout;
            like $stderr, qr{ERROR: SQL error in execute: called with 2 bind variables when 1 are needed};
            like $stderr, qr{\QQuery: SELECT * FROM person WHERE id=?}, 'stderr contains query';
            like $stderr, qr{\QBinds: 1, "foo"}, 'stderr contains bind variables';
            unlike $stderr, qr{Usage:}, "we don't need usage info";
        };

        subtest 'SQL error in prepare using --dsn' => sub {
            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( '--dsn', 'dbi:SQLite:dbname=' . $home->child( 'test.db' ), 'SELECT FROM person' );
            };
            isnt $exit, 0, 'error happened';
            ok !$stdout, 'nothing on stdout' or diag $stdout;
            like $stderr, qr{ERROR: SQL error in prepare: near "FROM": syntax error};
            like $stderr, qr{\QQuery: SELECT FROM person}, 'stderr contains query';
            unlike $stderr, qr{DBD::SQLite::db prepare failed:}, 'does not contain second error from DBI';
            unlike $stderr, qr{Usage:}, "we don't need usage info";
        };

        subtest 'placeholder bind failure in --insert helper' => sub {
            my $home = tempdir;
            local $ENV{HOME} = "$home";

            my $conf = {
                testdb => {
                    driver => 'SQLite',
                    database => $home->child( 'test.db' )->stringify,
                },
            };
            my $conf_file = $home->child( '.yertl', 'ysql.yml' );
            my $yaml = ETL::Yertl::Format::yaml->new;
            $conf_file->touchpath->spew( $yaml->format( $conf ) );

            my $dbh = DBI->connect( 'dbi:SQLite:dbname=' . $home->child( 'test.db' ) );
            $dbh->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
            local *STDIN = $SHARE_DIR->child( 'command', 'ysql', 'deep.yml' )->openr;

            my ( $stdout, $stderr, $exit ) = capture {
                ysql->main( 'testdb',
                    '--insert', 'person'
                );
            };
            ok $exit, 'nonzero exit on error';
            like $stderr, qr{\QERROR: Can't insert complex data structures using '--insert'}, 'stderr has error message';
            ok !$stdout, 'nothing on stdout' or diag $stdout;
        };
    };
};

done_testing;
