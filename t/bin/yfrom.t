
use App::YAML::Filter::Test;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use File::Spec;
use File::Temp qw( tempfile );

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
    plan skip_all => 'No JSON module installed (' . ( join ", ", yfrom->format_modules( 'json' ) ) . ')'
        unless yfrom->can_format( 'json' );

    my $text = <<ENDYML;
---
baz: buzz
foo: bar
---
flip:
  - flop
  - blip
ENDYML

    my $json = <<'ENDJSON';
{
  "baz" : "buzz",
  "foo" : "bar"
}
{
  "flip" : [
    "flop",
    "blip"
  ]
}
ENDJSON

    my ( $json_fh, $json_fn ) = tempfile();
    print {$json_fh} $json;
    seek $json_fh, 0, 0;

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'json', $json_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $text;
    };
    subtest 'stdin' => sub {
        local *STDIN = $json_fh;

        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'json' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $text;

        seek $json_fh, 0, 0;
    };
};

subtest 'CSV -> DOC' => sub {
    plan skip_all => 'No CSV module installed (' . ( join ", ", yfrom->format_modules( 'csv' ) ) . ')'
        unless yfrom->can_format( 'csv' );

    my $text = <<ENDYML;
---
bar: 2
baz: 3
foo: 1
---
bar: 5
baz: 6
foo: 4
---
bar: 8
baz: 9
foo: 7
ENDYML

    my $csv = <<'ENDJSON';
foo,bar,baz
1,2,3
4,5,6
7,8,9
ENDJSON

    my ( $csv_fh, $csv_fn ) = tempfile();
    print {$csv_fh} $csv;
    seek $csv_fh, 0, 0;

    subtest 'filename' => sub {
        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'csv', $csv_fn ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $text;
    };
    subtest 'stdin' => sub {
        local *STDIN = $csv_fh;

        my ( $stdout, $stderr, $exit ) = capture { yfrom->main( 'csv' ) };
        is $exit, 0, 'exit 0';
        ok !$stderr, 'nothing on stderr';
        eq_or_diff $stdout, $text;

        seek $csv_fh, 0, 0;
    };
};

done_testing;
