
use App::YAML::Filter::Base;
use Test::Most;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture_merged );
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
    my ( $output ) = capture_merged { yq->main( $filter ) };
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ $doc[0] ];
};

done_testing;
