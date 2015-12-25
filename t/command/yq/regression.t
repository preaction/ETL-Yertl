
use ETL::Yertl 'Test';
use ETL::Yertl::Command::yq;
my $class = 'ETL::Yertl::Command::yq';

subtest '#132: "select( .foo == 1 ) | .bar"' => sub {
    my @docs = (
        { foo => 1, bar => 'fuzz' },
        { foo => 2, bar => 'fizz' },
        { foo => 1, bar => 'buzz' },
    );
    my $filter = 'select( .foo == 1 ) | .bar';
    my $scope = {};
    my @out;
    push @out, $class->filter( $filter, $_, $scope ) for @docs;
    push @out, $class->finish( $scope );
    cmp_deeply \@out, [
        'fuzz',
        bless( {}, 'empty' ),
        'buzz',
    ] or diag explain \@out;
};

done_testing;
