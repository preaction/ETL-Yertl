
use ETL::Yertl 'Test';
use ETL::Yertl::Command::yq;
my $class = 'ETL::Yertl::Command::yq';

subtest 'filter single hash key' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = '.foo';
    my $out = $class->filter( $filter, $doc );
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
        my $out = $class->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'two levels' => sub {
        my $filter = '.foo.bar';
        my $out = $class->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest 'array key' => sub {
    my $doc = [qw( foo bar baz )];
    my $filter = '.[1]';
    my $out = $class->filter( $filter, $doc );
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
        my $out = $class->filter( $filter, $doc );
        cmp_deeply $out, [ { bar => 'baz' } ];
    };
    subtest 'hash,array level' => sub {
        my $filter = '.foo.[0]';
        my $out = $class->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'hash,array,hash level' => sub {
        my $filter = '.foo.[0].bar';
        my $out = $class->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest '[] with no index flattens an array' => sub {
    my $doc = {
        foo => [ 1, 2, 3 ],
        bar => [ 4, 5, 6 ],
    };
    my $filter = '.foo.[]';
    my @out = $class->filter( $filter, $doc );
    cmp_deeply \@out, [ 1, 2, 3 ];
};

subtest 'filter on empty results in empty' => sub {
    my $doc = bless {}, 'empty';
    my $filter = '.foo';
    my $out = $class->filter( $filter, $doc );
    isa_ok $out, 'empty';
};

subtest 'original document starts with $.' => sub {
    my $doc = {
        foo => 'bar',
        fizz => 'buzz',
    };
    my $filter = '$.foo';
    my $out = $class->filter( $filter, $doc );
    cmp_deeply $out, 'bar';

    subtest 'original document is always constant even through pipes' => sub {
        my $doc = {
            foo => {
                foo => 'baz',
            },
            fizz => 'buzz',
        };
        my $filter = '.foo | $.foo';
        my @out = $class->filter( $filter, $doc );
        cmp_deeply \@out, [ { foo => 'baz' } ];
    };
};

done_testing;
