
use App::YAML::Filter::Base;
use Test::Most;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use FindBin qw( $Bin );
use File::Spec;
require 'bin/yq';

subtest 'filter single hash key' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = '.foo';
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, 'bar';
};

subtest 'deep hash key' => sub {
    my $doc = {
        foo => {
            bar => 'baz',
        },
    };
    subtest 'one level' => sub {
        my $filter = '.foo';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'two levels' => sub {
        my $filter = '.foo.bar';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest 'array key' => sub {
    my $doc = [qw( foo bar baz )];
    my $filter = '.[1]';
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, 'bar';
};

subtest 'mixed array and hash keys' => sub {
    my $doc = {
        foo => [
            {
                bar => 'baz',
            },
        ]
    };
    subtest 'hash level' => sub {
        my $filter = '.foo';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, [ { bar => 'baz' } ];
    };
    subtest 'hash,array level' => sub {
        my $filter = '.foo.[0]';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'hash,array,hash level' => sub {
        my $filter = '.foo.[0].bar';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest ', emits multiple results' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = '.foo, .baz';
    my @out = yq->filter( $filter, $doc );
    cmp_deeply \@out, [ 'bar', 'fuzz' ];
};

subtest 'conditional match single hash key and return full document' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = 'if .foo eq bar then .';
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc;
};

subtest 'conditional with else' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = 'if .foo eq bar then .foo else .baz';
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc->{foo};

    $filter = 'if .foo eq buzz then .foo else .baz';
    $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc->{baz};
};

subtest 'empty' => sub {
    my $filter = 'empty';
    my $out = yq->filter( $filter, { foo => 'bar' } );
    isa_ok $out, 'empty';
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

done_testing;
