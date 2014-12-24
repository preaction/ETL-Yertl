
use ETL::Yertl::Test;
my $script = "$FindBin::Bin/../bin/yq";
require $script;

subtest 'filter single hash key' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = '.foo';
    my $out = yq->filter( $filter, $doc );
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
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'two levels' => sub {
        my $filter = '.foo.bar';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest 'array key' => sub {
    my $doc = [qw( foo bar baz )];
    my $filter = '.[1]';
    my $out = yq->filter( $filter, $doc );
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
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, [ { bar => 'baz' } ];
    };
    subtest 'hash,array level' => sub {
        my $filter = '.foo.[0]';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, { bar => 'baz' };
    };
    subtest 'hash,array,hash level' => sub {
        my $filter = '.foo.[0].bar';
        my $out = yq->filter( $filter, $doc );
        cmp_deeply $out, 'baz';
    };
};

subtest '[] with no index flattens an array' => sub {
    my $doc = {
        foo => [ 1, 2, 3 ],
        bar => [ 4, 5, 6 ],
    };
    my $filter = '.foo.[]';
    my @out = yq->filter( $filter, $doc );
    cmp_deeply \@out, [ 1, 2, 3 ];
};

done_testing;
