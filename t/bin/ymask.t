
use ETL::Yertl::Test;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use File::Spec;
use File::Temp qw( tempfile );

my $script = "$FindBin::Bin/../../bin/ymask";
require $script;
$0 = $script; # So pod2usage finds the right file

my $text = <<ENDYML;
foo: bar
baz: buzz
---
flip:
  - flop: 1
    blip: 2
  - flop: 3
    blip: 4
ENDYML

my @docs = Load( $text );
my $expect = <<ENDYML;
---
foo: bar
---
flip:
  - flop: 1
  - flop: 3
ENDYML

my ( $doc_fh, $doc_fn ) = tempfile();
print {$doc_fh} $text;
seek $doc_fh, 0, 0;

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ymask->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a mask}, 'contains error message';
    };
};

subtest 'input' => sub {

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { ymask->main( 'foo,flip/flop', $doc_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $expect;
    };

    subtest 'stdin' => sub {
        local *STDIN = $doc_fh;

        my ( $stdout, $stderr, $exit ) = capture { ymask->main( 'foo,flip/flop' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $expect;

        seek $doc_fh, 0, 0;
    };
};

done_testing;
