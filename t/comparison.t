
use ETL::Yertl 'Test';
my $script = "$FindBin::Bin/../bin/yq";
require $script;

my $doc = {
    foo => 'bar',
    baz => 'fuzz',
    buzz => 'bar',
    one => 1,
    two => 2,
    uno => 1,
};

subtest 'eq' => sub {
    subtest 'FILTER eq CONSTANT' => sub {
        my $out = yq->filter( '.foo eq bar', $doc );
        ok isTrue( $out );
        $out = yq->filter( '.foo eq "jump"', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER eq FILTER' => sub {
        my $out = yq->filter( '.foo eq .buzz', $doc );
        ok isTrue( $out );
        $out = yq->filter( '.foo eq .baz', $doc );
        ok isFalse( $out );
    };
};

subtest 'ne' => sub {
    subtest 'FILTER ne CONSTANT' => sub {
        my $out = yq->filter( ".foo ne 'bar'", $doc );
        ok isFalse( $out );
        $out = yq->filter( '.foo ne jump', $doc );
        ok isTrue( $out );
    };
    subtest 'FILTER ne FILTER' => sub {
        my $out = yq->filter( '.foo ne .buzz', $doc );
        ok isFalse( $out );
        $out = yq->filter( '.foo ne .baz', $doc );
        ok isTrue( $out );
    };
};

subtest '==' => sub {
    subtest 'FILTER == CONSTANT' => sub {
        my $out = yq->filter( ".one == 1", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one == 2', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER == FILTER' => sub {
        my $out = yq->filter( ".one == .uno", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one == .two', $doc );
        ok isFalse( $out );
    };
};

subtest '!=' => sub {
    subtest 'FILTER != CONSTANT' => sub {
        my $out = yq->filter( ".one != 2", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one != 1', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER != FILTER' => sub {
        my $out = yq->filter( ".one != .two", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one != .uno', $doc );
        ok isFalse( $out );
    };
};

subtest '>|>=' => sub {
    subtest 'FILTER > CONSTANT' => sub {
        my $out = yq->filter( ".one > 2", $doc );
        ok isFalse( $out );
        $out = yq->filter( ".one > 0", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one > 1', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER > FILTER' => sub {
        my $out = yq->filter( ".one > .two", $doc );
        ok isFalse( $out );
        $out = yq->filter( ".two > .one", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one > .uno', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER >= CONSTANT' => sub {
        my $out = yq->filter( ".one >= 2", $doc );
        ok isFalse( $out );
        $out = yq->filter( ".one >= 0", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one >= 1', $doc );
        ok isTrue( $out );
    };
    subtest 'FILTER >= FILTER' => sub {
        my $out = yq->filter( ".one >= .two", $doc );
        ok isFalse( $out );
        $out = yq->filter( ".two >= .one", $doc );
        ok isTrue( $out );
        $out = yq->filter( '.one >= .uno', $doc );
        ok isTrue( $out );
    };
};

subtest '<|<=' => sub {
    subtest 'FILTER < CONSTANT' => sub {
        my $out = yq->filter( ".one < 2", $doc );
        ok isTrue( $out );
        $out = yq->filter( ".one < 0", $doc );
        ok isFalse( $out );
        $out = yq->filter( '.one < 1', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER < FILTER' => sub {
        my $out = yq->filter( ".one < .two", $doc );
        ok isTrue( $out );
        $out = yq->filter( ".two < .one", $doc );
        ok isFalse( $out );
        $out = yq->filter( '.one < .uno', $doc );
        ok isFalse( $out );
    };
    subtest 'FILTER <= CONSTANT' => sub {
        my $out = yq->filter( ".one <= 2", $doc );
        ok isTrue( $out );
        $out = yq->filter( ".one <= 0", $doc );
        ok isFalse( $out );
        $out = yq->filter( '.one <= 1', $doc );
        ok isTrue( $out );
    };
    subtest 'FILTER <= FILTER' => sub {
        my $out = yq->filter( ".one <= .two", $doc );
        ok isTrue( $out );
        $out = yq->filter( ".two <= .one", $doc );
        ok isFalse( $out );
        $out = yq->filter( '.one <= .uno', $doc );
        ok isTrue( $out );
    };
};

done_testing;
