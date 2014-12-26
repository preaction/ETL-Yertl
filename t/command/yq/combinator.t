
use ETL::Yertl 'Test';
use ETL::Yertl::Command::yq;
my $class = 'ETL::Yertl::Command::yq';

subtest ', emits multiple results' => sub {
    subtest 'simple filters' => sub {
        my $doc = {
            foo => 'bar',
            baz => 'fuzz',
        };
        my $filter = ".foo, .baz, 'fizz'";
        my @out = $class->filter( $filter, $doc );
        cmp_deeply \@out, [ 'bar', 'fuzz', 'fizz' ];
    };
};

subtest '| gives output of one EXPR as input to another' => sub {
    subtest 'create document, pipe to group_by()' => sub {
        my @docs = (
            { foo => 'bar', baz => 'fuzz' },
            { foo => 'bar', baz => 'fizz' },
            { foo => 'foo', baz => 'buzz' },
        );
        my $filter = '{ foo: .foo } | group_by( .foo )';
        my $scope = {};
        my @out;
        push @out, $class->filter( $filter, $_, $scope ) for @docs;
        push @out, $class->finish( $scope );
        cmp_deeply \@out, [
            {
                bar => [
                    { foo => 'bar' },
                    { foo => 'bar' },
                ],
                foo => [
                    { foo => 'foo' },
                ],
            },
        ] or diag explain \@out;
    };
};

done_testing;
