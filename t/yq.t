
use ETL::Yertl::Test;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use File::Spec;

my $script = "$FindBin::Bin/../bin/yq";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'help options' => sub {
    my ( $out, $err, $exit ) = capture { yq->main( '-h' ) };
    is $exit, 0, 'successfully showed the help';
    ok !$err, 'requested help is on stdout';
    like $out, qr{Usage:}, 'synopsis is included';
    like $out, qr{Arguments:}, 'arguments are included';
    like $out, qr{Options:}, 'options are included';
};

subtest 'must provide a filter' => sub {
    my ( $out, $err, $exit ) = capture { yq->main };
    is $exit, 2, 'fatal error';
    ok !$out, 'errors are on stderr';
    like $err, qr{ERROR: Must give a filter};
    like $err, qr{Usage:};
};

subtest 'empty does not print' => sub {
    my @doc = (
        {
            foo => 'bar',
        },
        {
            bar => 'baz',
        },
    );

    open my $stdin, '<', \( YAML::Dump( @doc ) );
    local *STDIN = $stdin;
    my $filter = 'if .foo eq bar then . else empty';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ $doc[0] ];
};

subtest 'single document with no --- separator' => sub {
    my $doc = <<ENDYML;
foo: bar
baz: buzz
flip:
    - flop
    - blip
ENDYML
    open my $stdin, '<', \$doc;
    local *STDIN = $stdin;
    my $filter = '.flip.[0]';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'flop' ];
};

subtest 'file in ARGV' => sub {
    my $file = File::Spec->catfile( $Bin, 'share', 'foo.yml' );
    my $filter = '.foo';
    my ( $output, $stderr ) = capture { yq->main( $filter, $file ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'bar' ];
};

subtest 'multiple documents print properly' => sub {
    my $doc = <<ENDYML;
foo: bar
baz: buzz
ENDYML
    open my $stdin, '<', \$doc;
    local *STDIN = $stdin;
    my $filter = '.foo, .baz';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'bar', 'buzz' ];
};

subtest 'finish() gets called' => sub {
    my $docs = <<ENDYML;
---
foo: 'bar'
baz: 1
---
foo: 'bar'
baz: 2
---
foo: 'baz'
baz: 3
ENDYML
    open my $stdin, '<', \$docs;
    local *STDIN = $stdin;
    my $filter = 'group_by( .foo )';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );

    cmp_deeply \@got, [
        {
            bar => [
                {
                    foo => 'bar',
                    baz => 1,
                },
                {
                    foo => 'bar',
                    baz => 2,
                },
            ],
            baz => [
                {
                    foo => 'baz',
                    baz => 3,
                },
            ],
        },
    ];
};

subtest 'version check' => sub {
    local $yq::VERSION = '1.00';
    my ( $output, $stderr, $exit ) = capture { yq->main( '--version' ) };
    is $exit, 0;
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    is $output, "yq version 1.00 (Perl $^V)\n";
};

done_testing;
