
use ETL::Yertl 'Test';
use ETL::Yertl::Transform::Yq;
my $class = 'ETL::Yertl::Transform::Yq';

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

subtest 'each( EXPR )' => sub {
    my $doc = {
        foo => {
            one => 1,
            two => 2,
            three => 3,
        },
        baz => [ 3, 2, 1 ],
    };

    subtest 'each of whole document' => sub {
        my @out = $class->filter( 'each( . )', $doc );
        cmp_deeply \@out, bag(
            { key => 'foo', value => $doc->{foo} },
            { key => 'baz', value => $doc->{baz} },
        );
    };

    subtest 'each of hash inside document' => sub {
        my @out = $class->filter( 'each( .foo )', $doc );
        cmp_deeply \@out, bag(
            { key => 'one', value => 1 },
            { key => 'two', value => 2 },
            { key => 'three', value => 3 },
        );
    };

    subtest 'each of array inside document' => sub {
        my @out = $class->filter( 'each( .baz )', $doc );
        cmp_deeply \@out, bag(
            { key => '0', value => 3 },
            { key => '1', value => 2 },
            { key => '2', value => 1 },
        );
    };

    subtest 'keys with no args -> keys(.)' => sub {
        my @out = $class->filter( 'each( . )', $doc );
        cmp_deeply \@out, bag(
            { key => 'foo', value => $doc->{foo} },
            { key => 'baz', value => $doc->{baz} },
        );
    };

    subtest 'allow assignment' => sub {
        my @out = $class->filter( 'each | .value = 2', $doc );
        cmp_deeply \@out, bag(
            { key => 'foo', value => 2 },
            { key => 'baz', value => 2 },
        );
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

    subtest 'length of all arrays in a hash' => sub {
        my $doc = {
            foo => [ 1..5 ],
            bar => [ 1..4 ],
            baz => [ 1..10 ],
        };
        my @out;
        eval {
            @out = $class->filter( 'each | .value = length( .value )', $doc );
        };
        ok !$@, 'filter ran successfully' or diag $@;
        cmp_deeply \@out, bag(
            { key => 'foo', value => 5 },
            { key => 'bar', value => 4 },
            { key => 'baz', value => 10 },
        ) or diag explain \@out;
    };

    subtest 'get arrays of certain length' => sub {
        my $doc = {
            foo => [ 1..5 ],
            bar => [ 1..4 ],
            baz => [ 1..10 ],
        };
        my @out;
        eval {
            @out = $class->filter( 'each | select( length( .value ) >= 5 )', $doc );
        };
        ok !$@, 'filter ran successfully' or diag $@;
        cmp_deeply \@out, bag(
            bless( {}, 'empty' ),
            { key => 'foo', value => [ 1..5 ] },
            { key => 'baz', value => [ 1..10 ] },
        ) or diag explain \@out;
    };
};

subtest 'date/time functions' => sub {

    my $epoch = 1483228800;
    my %parse_formats = (
        iso => [
            '2017-01-01T00:00:00',
            '2017-01-01 00:00:00',
            '2017-01-01',
            '20170101000000',
            '201701010000',
            '20170101',
        ],
        # http => [
        #     'Sun, 01 Jan 2017 00:00:00 GMT', # Current HTTP date
        #     'Sunday, 01-Jan-17 00:00:00 GMT', # Obsolete HTTP date
        #     'Sun Jan  1 00:00:00 2017', # Obsolete HTTP date
        #     '01/Jan/2017:00:00:00 -0000', # Common Log Format
        # ],
        apache => [
            '01/Jan/2017:00:00:00 -0000', # Common Log Format
        ],
        # mail => [
        #     'Sun, 01 Jan 2017 00:00:00', # RFC2822 date
        # ],
    );

    my $test_parse = sub {
        my ( $str, $format ) = @_;
        $format ||= '';
        if ( $format ) {
            $format = ", $format";
        }
        my $doc = {
            timestamp => $str,
        };
        my @out;
        eval {
            @out = $class->filter( ".timestamp = parse_time( .timestamp$format )", $doc );
        };
        ok !$@, 'filter ran successfully' or diag $@;
        cmp_deeply \@out, bag(
            { timestamp => 1483228800 },
        ) or diag explain \@out;
    };

    subtest 'parse_time' => sub {
        for my $format ( keys %parse_formats ) {
            for my $str ( @{ $parse_formats{ $format } } ) {
                subtest "parse format $format - $str" => $test_parse, $str, $format;
                subtest "parse format $format - $str (autodetect)" => $test_parse, $str;
            }
        }
    };

};

done_testing;
