
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/yto";
require $script;
$0 = $script; # So pod2usage finds the right file

my $doc_fn = $SHARE_DIR->child( yaml => 'test.yaml' );

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a format}, 'contains error message';
    };
    subtest 'unknown format' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main( "$doc_fn" ) };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Unknown format '$doc_fn'}, 'contains error message';
    };
};

subtest 'DOC -> JSON' => sub {
    my @expect = docs_from_string( yaml => $doc_fn->slurp );

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main( 'json', $doc_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        cmp_deeply [ docs_from_string( json => $stdout ) ], \@expect;
    };

    subtest 'stdin' => sub {
        local *STDIN = $doc_fn->openr;

        my ( $stdout, $stderr, $exit ) = capture { yto->main( 'json' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;

        cmp_deeply [ docs_from_string( json => $stdout ) ], \@expect;
    };
};

done_testing;
