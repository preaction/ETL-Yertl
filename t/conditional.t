
use ETL::Yertl::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

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

    $filter = 'if .foo eq "buzz" then .foo else .baz';
    $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc->{baz};
};

done_testing;
