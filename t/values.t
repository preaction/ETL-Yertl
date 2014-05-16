
use App::YAML::Filter::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

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
