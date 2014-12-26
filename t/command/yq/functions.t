
use ETL::Yertl 'Test';
use ETL::Yertl::Command::yq;
my $class = 'ETL::Yertl::Command::yq';

my $doc = {
    foo => 'bar',
    baz => 'fuzz',
};

subtest 'select( EXPR )' => sub {
    my $filter = 'select( .foo eq bar )';
    my $out = $class->filter( $filter, $doc );
    cmp_deeply $out, $doc;
};

subtest 'grep( EXPR )' => sub {
    my $filter = "grep( .foo eq 'bar' )";
    my $out = $class->filter( $filter, $doc );
    cmp_deeply $out, $doc;
};

subtest 'empty' => sub {
    my $out = $class->filter( 'empty', $doc );
    isa_ok $out, 'empty';
};

subtest 'group_by( EXPR )' => sub {
    my @docs = (
        {
            foo => 'bar',
            baz => 1,
        },
        {
            foo => 'bar',
            baz => 2,
        },
        {
            foo => 'baz',
            baz => 3,
        },
    );
    my $scope = {};
    for my $doc ( @docs ) {
        my $out = $class->filter( 'group_by( .foo )', $doc, $scope );
        ok !$out, 'group_by delays output';
    }

    cmp_deeply $scope, {
        group_by => {
            bar => [ @docs[0..1] ],
            baz => [ $docs[2] ],
        },
    };

    my @out = $class->finish( $scope );
    cmp_deeply $out[0], { bar => [ @docs[0..1] ], baz => [ $docs[2] ] };
};

subtest 'sort( EXPR )' => sub {
    my @docs = (
        {
            foo => 'bar',
            baz => 1,
        },
        {
            foo => 'baq',
            baz => 2,
        },
        {
            foo => 'baz',
            baz => 3,
        },
    );
    subtest 'sort by string' => sub {
        my $scope = {};
        for my $doc ( @docs ) {
            my $out = $class->filter( 'sort( .foo )', $doc, $scope );
            ok !$out, 'sort delays output';
        }
        my @out = $class->finish( $scope );
        cmp_deeply \@out, [ @docs[1,0,2] ]
    };
};

subtest 'keys( EXPR )' => sub {
    my $doc = {
        foo => {
            one => 1,
            two => 2,
            three => 3,
        },
        baz => [ 3, 2, 1 ],
    };

    subtest 'keys of whole document' => sub {
        my $out = $class->filter( 'keys( . )', $doc );
        cmp_deeply $out, bag(qw( foo baz ));
    };

    subtest 'keys of hash inside document' => sub {
        my $out = $class->filter( 'keys( .foo )', $doc );
        cmp_deeply $out, bag(qw( one two three ));
    };

    subtest 'keys of array inside document' => sub {
        my $out = $class->filter( 'keys( .baz )', $doc );
        cmp_deeply $out, bag(qw( 0 1 2 ));
    };

    subtest 'keys with no args -> keys(.)' => sub {
        my $out = $class->filter( 'keys', $doc );
        cmp_deeply $out, bag(qw( foo baz ));
    };

    subtest 'allow assignment' => sub {
        my $out = $class->filter( '{ k: keys( .foo ) }', $doc );
        cmp_deeply $out, { k => bag(qw( one two three )) };
    };
};

subtest 'length( EXPR )' => sub {
    my $doc = {
        foo => {
            one => 1,
            two => 'onetwothreefourfive',
            three => 3,
        },
        baz => [ 3, 2, 1 ],
    };

    subtest 'length of whole document (hash)' => sub {
        my $out = $class->filter( 'length(.)', $doc );
        is $out, 2;
    };
    subtest 'length with no args -> length(.)' => sub {
        my $out = $class->filter( 'length', $doc );
        is $out, 2;
    };
    subtest 'length of inner hash (# of pairs)' => sub {
        my $out = $class->filter( 'length( .foo )', $doc );
        is $out, 3;
    };
    subtest 'length of array' => sub {
        my $out = $class->filter( 'length( .baz )', $doc );
        is $out, 3;
    };
    subtest 'length of string' => sub {
        my $out = $class->filter( 'length( .foo.two )', $doc );
        is $out, 19;
    };
    subtest 'length of number' => sub {
        my $out = $class->filter( 'length( .baz.[0] )', $doc );
        is $out, 1;
    };
    subtest 'allow assignment' => sub {
        my $out = $class->filter( '{ l: length( .foo.two ) }', $doc );
        cmp_deeply $out, { l => 19 };
    };
};

done_testing;
