
use ETL::Yertl 'Test';
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use File::Spec;
use File::Temp qw( tempfile );

my $script = "$FindBin::Bin/../../bin/yto";
require $script;
$0 = $script; # So pod2usage finds the right file

my $text = <<ENDYML;
foo: bar
baz: buzz
---
flip:
  - flop
  - blip
ENDYML

my $json = qr{\Q{
   "baz" : "buzz",
   "foo" : "bar"
}\E\n*\Q
{
   "flip" : [
      "flop",
      "blip"
   ]
}\E};

my @docs = Load( $text );

my ( $doc_fh, $doc_fn ) = tempfile();
print {$doc_fh} $text;
seek $doc_fh, 0, 0;

subtest 'error checking' => sub {
    subtest 'no arguments' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main() };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Must give a format}, 'contains error message';
    };
    subtest 'unknown format' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main( $doc_fn ) };
        isnt $exit, 0, 'error status';
        like $stderr, qr{ERROR: Unknown format '$doc_fn'}, 'contains error message';
    };
};

subtest 'DOC -> JSON' => sub {
    # JSON::PP is a test requirement

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yto->main( 'json', $doc_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        like $stdout, $json;
    };

    subtest 'stdin' => sub {
        local *STDIN = $doc_fh;

        my ( $stdout, $stderr, $exit ) = capture { yto->main( 'json' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr' or diag $stderr;
        like $stdout, $json;

        seek $doc_fh, 0, 0;
    };
};

done_testing;
