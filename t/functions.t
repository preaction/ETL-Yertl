
use App::YAML::Filter::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

my $doc = {
    foo => 'bar',
    baz => 'fuzz',
};

subtest 'select( EXPR )' => sub {
    my $filter = 'select( .foo eq bar )';
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc;
};

subtest 'grep( EXPR )' => sub {
    my $filter = "grep( .foo eq 'bar' )";
    my $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc;
};

subtest 'empty' => sub {
    my $out = yq->filter( 'empty', $doc );
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
        my $out = yq->filter( 'group_by( .foo )', $doc, $scope );
        ok !$out, 'group_by delays output';
    }

    cmp_deeply $scope, {
        group_by => {
            bar => [ @docs[0..1] ],
            baz => [ $docs[2] ],
        },
    };

    my @out = yq->finish( $scope );
    cmp_deeply $out[0], { bar => [ @docs[0..1] ], baz => [ $docs[2] ] };
};

done_testing;
