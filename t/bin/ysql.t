
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/ysql";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ysql->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a command}, 'contains error message';
    };
};

subtest 'query' => sub {
    my $tmp = tempfile;
    my $dbi = DBI->connect( 'dbi:SQLite:dbname=' . $tmp );
    $dbi->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
    my @people = (
        [ 1, 'Hazel Murphy', 'hank@example.com' ],
        [ 2, 'Quentin Quinn', 'quinn@example.com' ],
    );
    my $sql_people = join ", ", map { sprintf '( %d, "%s", "%s" )', @$_ } @people;
    $dbi->do( 'INSERT INTO person ( id, name, email ) VALUES ' . $sql_people );

    subtest 'basic query' => sub {
        my ( $stdout, $stderr, $exit ) = capture {
            ysql->main( 'query', '--dsn', 'dbi:SQLite:dbname=' . $tmp, 'SELECT * FROM person' );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], bag(
            {
                id => 1,
                name => 'Hazel Murphy',
                email => 'hank@example.com',
            },
            {
                id => 2,
                name => 'Quentin Quinn',
                email => 'quinn@example.com',
            },
        );
    };

};

subtest 'write' => sub {

    subtest 'basic write' => sub {
        my $tmp = tempfile;
        my $dbi = DBI->connect( 'dbi:SQLite:dbname=' . $tmp );
        $dbi->do( 'CREATE TABLE person ( id INT, name VARCHAR, email VARCHAR )' );
        local *STDIN = $SHARE_DIR->child( 'command', 'ysql', 'write.yml' )->openr;

        my ( $stdout, $stderr, $exit ) = capture {
            ysql->main( '--dsn', 'dbi:SQLite:dbname=' . $tmp, 'write',
                'INSERT INTO person (id, name, email) VALUES ($.id, $.name, $.email)',
            );
        };
        is $exit, 0;
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        ok !$stdout, 'nothing on stdout' or diag $stdout;

        cmp_deeply
            $dbi->selectall_arrayref( 'SELECT id,name,email FROM person' ),
            bag(
                [ 1, 'Hazel Murphy', 'hank@example.com' ],
                [ 2, 'Quentin Quinn', 'quinn@example.com' ],
            );
    };

};


done_testing;
