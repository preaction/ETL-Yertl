
use ETL::Yertl 'Test';
use Capture::Tiny qw( capture );
use ETL::Yertl::Format::yaml;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $script = "$FindBin::Bin/../../bin/ymask";
require $script;
$0 = $script; # So pod2usage finds the right file

my $doc_fn = $SHARE_DIR->child(qw( command ymask in.yaml ));
my @expect = (
    { foo => 'bar' },
    { flip => [ { flop => 1 }, { flop => 3 } ] },
);

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ymask->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a mask}, 'contains error message';
    };
};

subtest 'input' => sub {

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ymask->main( 'foo,flip/flop', "$doc_fn" ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@expect;
    };

    subtest 'stdin' => sub {
        local *STDIN = $doc_fn->openr;

        my ( $stdout, $stderr, $exit ) = capture { ymask->main( 'foo,flip/flop' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        open my $fh, '<', \$stdout;
        my $yaml_fmt = ETL::Yertl::Format::yaml->new( input => $fh );
        cmp_deeply [ $yaml_fmt->read ], \@expect;
    };
};

done_testing;
