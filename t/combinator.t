
use ETL::Yertl::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

subtest ', emits multiple results' => sub {
    subtest 'simple filters' => sub {
        my $doc = {
            foo => 'bar',
            baz => 'fuzz',
        };
        my $filter = ".foo, .baz, 'fizz'";
        my @out = yq->filter( $filter, $doc );
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
        push @out, yq->filter( $filter, $_, $scope ) for @docs;
        push @out, yq->finish( $scope );
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
