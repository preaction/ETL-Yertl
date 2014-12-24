
use ETL::Yertl 'Test';
my $script = "$FindBin::Bin/../bin/yq";
require $script;

subtest 'raw numbers' => sub {
    my $doc = {
        foo => 3,
        bar => 2.482,
        baz => 1.345e10,
        fuzz => 0b0010,
        fizz => 037,
        trap => 0xab3,
        minus => -0.123,
    };
    subtest 'integers' => sub {
        my $out = yq->filter( '.foo == 3', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'decimals' => sub {
        my $out = yq->filter( '.bar == 2.482', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'exponential' => sub {
        my $out = yq->filter( '.baz == 1.345e10', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'binary' => sub {
        my $out = yq->filter( '.fuzz == 0b0010', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'octal' => sub {
        my $out = yq->filter( '.fizz == 037', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'hex' => sub {
        my $out = yq->filter( '.trap == 0xab3', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'negative' => sub {
        my $out = yq->filter( '.minus == -0.123', $doc );
        ok isTrue( $out ) or diag $out;
    };
};

subtest 'hash constructor' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
        buzz => 'bar',
    };
    my @out = yq->filter( '{ bar: .foo, .buzz: "far/", doc: .baz }', $doc );
    cmp_deeply \@out, [
        {
            bar => $doc->{foo},
            $doc->{buzz} => 'far/',
            doc => $doc->{baz},
        },
    ] or diag explain \@out;
};

subtest 'array constructor' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
        buzz => 'bar',
    };
    my @out = yq->filter( '[ .foo, .buzz, doc, .baz, "bo/ck" ]', $doc );
    cmp_deeply \@out, [
        [
            $doc->{foo},
            $doc->{buzz},
            'doc',
            $doc->{baz},
            "bo/ck",
        ],
    ] or diag explain \@out;
};

done_testing;
