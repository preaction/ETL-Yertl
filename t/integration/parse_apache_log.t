
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Command::ygrok;
use File::Temp;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $yq_script = "$FindBin::Bin/../../bin/yq";
require $yq_script;

# XXX: This should use the Perl API, but before it does, we need
# to support:
#   - Arrayref as an input (to feed in lines or documents)
#   - String as an input (to feed in file content)
#   - Arrayref as an output (to examine transformed documents)
#   - Path::Tiny as input / output
#   - ygrok as a transform (LineStream source, on_doc destination)
sub test_command {
    my ( $cmd, %args ) = @_;

    if ( my $stdin = delete $args{stdin} ) {
        my $fh;
        if ( ref $stdin eq 'Path::Tiny' ) {
            $fh = $stdin->openr;
        }
        elsif ( ref $stdin eq 'ARRAY' ) {
            my $fmt = ETL::Yertl::Format->get( 'yaml' );
            my $yaml = join "", map { $fmt->format( $_ ) } @$stdin;
            $fh = File::Temp->new;
            print { $fh } $yaml;
            seek $fh, 0, 0;
        }
        else {
            $fh = File::Temp->new;
            print { $fh } $stdin;
            seek $fh, 0, 0;
        }
        local *STDIN = $fh;
        return test_command( $cmd, %args );
    }

    my ( $stdout, $stderr, $exit ) = capture {
        $cmd->main( @{ $args{args} || [] } );
    };
    ok !$exit, 'nothing returned';
    ok !$stderr, 'nothing on stderr' or diag $stderr;
    my @docs = docs_from_string( $stdout );
    return \@docs;
}

my $docs;

subtest '1: parse apache log with ygrok' => sub {
    my $file = $SHARE_DIR->child( lines => 'http_common_log.txt' );
    my $pattern = '%{LOG.HTTP_COMMON}';
    $docs = test_command( 'ETL::Yertl::Command::ygrok', stdin => $file, args => [ $pattern ] );
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
