
use App::YAML::Filter::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

subtest ', emits multiple results' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = ".foo, .baz, 'fizz'";
    my @out = yq->filter( $filter, $doc );
    cmp_deeply \@out, [ 'bar', 'fuzz', 'fizz' ];
};

done_testing;
