
use ETL::Yertl 'Test';
use ETL::Yertl::Command::yq;
my $class = 'ETL::Yertl::Command::yq';

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
        my $out = $class->filter( '.foo == 3', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'decimals' => sub {
        my $out = $class->filter( '.bar == 2.482', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'exponential' => sub {
        my $out = $class->filter( '.baz == 1.345e10', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'binary' => sub {
        my $out = $class->filter( '.fuzz == 0b0010', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'octal' => sub {
        my $out = $class->filter( '.fizz == 037', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'hex' => sub {
        my $out = $class->filter( '.trap == 0xab3', $doc );
        ok isTrue( $out ) or diag $out;
    };
    subtest 'negative' => sub {
        my $out = $class->filter( '.minus == -0.123', $doc );
        ok isTrue( $out ) or diag $out;
    };
};

subtest 'hash constructor' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
        buzz => 'bar',
    };
    my @out = $class->filter( '{ bar: .foo, .buzz: "far/", doc: .baz }', $doc );
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
    my @out = $class->filter( '[ .foo, .buzz, doc, .baz, "bo/ck" ]', $doc );
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

subtest 'assignment operator' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };

    subtest '<filter> = <filter>' => sub {
        my @out = $class->filter( '.foo = .baz', $doc );
        cmp_deeply \@out, [ { foo => 'fuzz', baz => 'fuzz' } ]
            or diag explain \@out;
    };

    subtest '<filter> = <number>' => sub {
        my @out = $class->filter( '.foo = 2', $doc );
        cmp_deeply \@out, [ { foo => '2', baz => 'fuzz' } ]
            or diag explain \@out;
    };

    subtest '<filter> = <string>' => sub {
        my @out = $class->filter( '.foo = "baz"', $doc );
        cmp_deeply \@out, [ { foo => 'baz', baz => 'fuzz' } ]
            or diag explain \@out;
    };

    subtest 'combine assignments with |' => sub {
        my @out = $class->filter( '.foo = "baz" | .baz = 2', $doc );
        cmp_deeply \@out, [ { foo => 'baz', baz => 2 } ]
            or diag explain \@out;
    };
};

done_testing;
