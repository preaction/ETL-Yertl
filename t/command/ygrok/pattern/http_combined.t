
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

subtest 'http combined log format' => sub {
    my $file = $SHARE_DIR->child( lines => 'http_combined_log.txt' );
    my $pattern = join " ", '%{LOG.HTTP_COMMON}',
                            '"%{URL:referer}"', '"%{DATA:user_agent}"',
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
            referer => 'http://example.com/referer',
            user_agent => 'Mozilla/5.0 And A Lot of Other Stuff',
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
            referer => '-',
            user_agent => 'Mojolicious/5.1',
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
            referer => '/blog',
            user_agent => 'Mozilla/4.2 (Compatible; MSIE 5.0)',
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
            referer => '-',
            user_agent => 'GoogleBot/1.0',
        },

        {
            remote_addr => 'bonzi.example.com',
            ident => '-',
            user => 'morty',
            timestamp => '04/Mar/2015:12:24:38 -0600',
            method => 'read',
            path => '/ping',
            http_version => '1.16.2',
            status => '200',
            content_length => '-',
            referer => '-',
            user_agent => 'Github/1.2 Something/2.4 Other/0.0',
        },
    );

    test_ygrok( $file, $pattern, \@expect );
    test_ygrok( $file, "%{LOG.HTTP_COMBINED}", \@expect )
};

done_testing;
