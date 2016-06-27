
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/ygrok";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a pattern}, 'contains error message';
    };
};

sub test_ygrok {
    my ( $file, $pattern, $expect, $args ) = @_;

    $args ||= [];

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( @$args, $pattern, $file ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( @$args, $pattern ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;
    };
}

subtest 'parse lines' => sub {
    my $file = $SHARE_DIR->child( lines => 'irc.txt' );
    my $pattern = '%{DATE.ISO8601:timestamp} %{WORD:user}@%{NET.IPV4:ip}> %{DATA:text}';
    my @expect = (
        {
            timestamp => '2014-01-01T00:00:00Z',
            user => 'preaction',
            ip => '127.0.0.1',
            text => 'Hello, world!',
        },
        {
            timestamp => '2014-01-01T00:15:24Z',
            user => 'jberger',
            ip => '127.0.1.1',
            text => 'Hello, preaction!',
        },
        {
            timestamp => '2014-01-01T01:14:51Z',
            user => 'preaction',
            ip => '127.0.0.1',
            text => 'Hello, jberger!',
        },
    );

    test_ygrok( $file, $pattern, \@expect );

    subtest 'loose parsing' => sub {
        my $file = $SHARE_DIR->child( lines => 'irc.txt' );
        my $pattern = '> %{DATA:text}$';
        my @expect = (
            {
                text => 'Hello, world!',
            },
            {
                text => 'Hello, preaction!',
            },
            {
                text => 'Hello, jberger!',
            },
        );

        test_ygrok( $file, $pattern, \@expect, [ '-l' ] );
    };
};

done_testing;
