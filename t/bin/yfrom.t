
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/yfrom";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a format}, 'contains error message';
    };
    subtest 'unknown format' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( "thisisabadformat" ) };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Unknown format 'thisisabadformat'}, 'contains error message';
    };
};

subtest 'JSON -> DOC' => sub {
    my $json_fn = $SHARE_DIR->child( json => 'test.json' );
    my @expect = (
        { baz => 'buzz', foo => 'bar' },
        { flip => [qw( flop blip )] },
        [qw( foo bar baz )],
    );

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'json', $json_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@expect;
    };

    subtest 'stdin' => sub {
        local *STDIN = $json_fn->openr;
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'json' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@expect;
    };
};

done_testing;
