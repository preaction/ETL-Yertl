
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
    my ( $file, $pattern, $expect ) = @_;

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( $pattern, $file ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        my @docs = $yaml_fmt->read;
        cmp_deeply \@docs, $expect or diag explain \@docs;;
    };

    subtest 'stdin' => sub {
        local *STDIN = $file->openr;
        my ( $stdout, $stderr, $exit ) = capture { ygrok->main( $pattern ) };
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
    my $pattern = '%{DATETIME:timestamp} %{WORD:user}@%{IPV4:ip}> %{DATA:text}';
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
};

subtest 'http logs' => sub {
    my $file = $SHARE_DIR->child( lines => 'http_common_log.txt' );
    my $pattern = join " ", '%{HOSTNAME:remote_addr}', '%{USER:ident}', '%{USER:user}',
                            '\[%{DATETIME_HTTP:timestamp}]',
                            '"%{WORD:method} %{URL_PATH:path} HTTP/%{NUM:http_version}"',
                            '%{INT:status}', '%{INT:content_length}',
                            ;

    my @expect = (
        {
            remote_addr => 'www.preaction.me',
            ident => 'doug',
            user => 'preaction',
            timestamp => '10/Oct/2000:13:55:36 -0700',
            method => 'GET',
            path => '/',
            http_version => '1.0',
            status => '200',
            content_length => 2326,
        },

        {
            remote_addr => '127.0.1.1',
            ident => '-',
            user => 'jberger',
            timestamp => '21/Nov/2001:18:02:42 -0800',
            method => 'GET',
            path => '/foo/bar/baz?fizz=no&buzz=yes',
            http_version => '1.1',
            status => '200',
            content_length => 236,
        },

        {
            remote_addr => '127.0.0.1',
            ident => '-',
            user => 'preaction',
            timestamp => '01/Jan/2002:13:55:36 +0500',
            method => 'POST',
            path => '/blog/edit',
            http_version => '1.1',
            status => '200',
            content_length => 326,
        },

        {
            remote_addr => '127.1.0.1',
            ident => '-',
            user => 'murphy',
            timestamp => '24/Jun/2015:06:12:36 -0000',
            method => 'GET',
            path => '/NOT_FOUND',
            http_version => '1.0',
            status => '404',
            content_length => 124,
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{COMMONLOG}", \@expect )
};

done_testing;
