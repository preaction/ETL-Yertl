
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
use ETL::Yertl::Command::ygrok;
use ETL::Yertl::Command::yq;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

# XXX: This could be moved into a test utility module and clean up a lot
# of test code!
# XXX: This could also be the start of a pure-Perl API to the commands!!
sub test_command {
    my ( $cmd, %args ) = @_;

    if ( my $stdin = delete $args{stdin} ) {
        my $fh;
        if ( ref $stdin eq 'Path::Tiny' ) {
            $fh = $stdin->openr;
        }
        elsif ( ref $stdin eq 'ARRAY' ) {
            my $yaml = ETL::Yertl::Format::yaml->new->write( @{ $stdin } );
            open $fh, '<', \$yaml;
        }
        else {
            open $fh, '<', \$stdin;
        }
        local *STDIN = $fh;
        return test_command( $cmd, %args );
    }

    my ( $stdout, $stderr, $exit ) = capture {
        "ETL::Yertl::Command::$cmd"->main( @{ $args{args} || [] } );
    };
    ok !$exit, 'nothing returned';
    ok !$stderr, 'nothing on stderr' or diag $stderr;
    open my $fh, '<', \$stdout;
    my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
    my @docs = $yaml_fmt->read;
    return \@docs;
}

my $docs;

subtest '1: parse apache log with ygrok' => sub {
    my $file = $SHARE_DIR->child( lines => 'http_common_log.txt' );
    my $pattern = '%{LOG.HTTP_COMMON}';
    $docs = test_command( 'ygrok', stdin => $file, args => [ $pattern ] );
};

subtest '2: parse apache date with yq' => sub {
    my $filter = '.timestamp = parse_time( .timestamp )';
    $docs = test_command( 'yq', stdin => $docs, args => [ $filter ] );
};

my @expect = (
    {
        remote_addr => 'www.preaction.me',
        ident => 'doug',
        user => 'preaction',
        timestamp => 971186136,
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
        timestamp => 1006365762,
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
        timestamp => 1009893336,
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
        timestamp => 1435126356,
        method => 'GET',
        path => '/NOT_FOUND',
        http_version => '1.0',
        status => '404',
        content_length => 124,
    },

    {
        remote_addr => 'bonzi.example.com',
        ident => '-',
        user => 'morty',
        timestamp => 1425471878,
        method => 'read',
        path => '/ping',
        http_version => '1.16.2',
        status => '200',
        content_length => '-',
    },
);

cmp_deeply $docs, \@expect, 'got expected output';

done_testing;
