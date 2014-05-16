
use App::YAML::Filter::Base;
use Test::Most;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use FindBin qw( $Bin );
use File::Spec;
use boolean qw( :all );

my $script = "$FindBin::Bin/../bin/yq";
require $script;
$0 = $script; # So pod2usage finds the right file

subtest 'help options' => sub {
    my ( $out, $err, $exit ) = capture { yq->main( '-h' ) };
    is $exit, 0, 'successfully showed the help';
    ok !$err, 'requested help is on stdout';
    like $out, qr{Usage:}, 'synopsis is included';
    like $out, qr{Arguments:}, 'arguments are included';
    like $out, qr{Options:}, 'options are included';
};

subtest 'must provide a filter' => sub {
    my ( $out, $err, $exit ) = capture { yq->main };
    is $exit, 2, 'fatal error';
    ok !$out, 'errors are on stderr';
    like $err, qr{ERROR: Must give a filter};
    like $err, qr{Usage:};
};

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

subtest ', emits multiple results' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
    };
    my $filter = ".foo, .baz, 'fizz'";
    my @out = yq->filter( $filter, $doc );
    cmp_deeply \@out, [ 'bar', 'fuzz', 'fizz' ];
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

subtest 'binary comparison operators' => sub {
    my $doc = {
        foo => 'bar',
        baz => 'fuzz',
        buzz => 'bar',
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
};

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

subtest 'functions' => sub {
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
};

subtest 'empty does not print' => sub {
    my @doc = (
        {
            foo => 'bar',
        },
        {
            bar => 'baz',
        },
    );

    open my $stdin, '<', \( YAML::Dump( @doc ) );
    local *STDIN = $stdin;
    my $filter = 'if .foo eq bar then . else empty';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ $doc[0] ];
};

subtest 'single document with no --- separator' => sub {
    my $doc = <<ENDYML;
foo: bar
baz: buzz
flip:
    - flop
    - blip
ENDYML
    open my $stdin, '<', \$doc;
    local *STDIN = $stdin;
    my $filter = '.flip.[0]';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'flop' ];
};

subtest 'file in ARGV' => sub {
    my $file = File::Spec->catfile( $Bin, 'share', 'foo.yml' );
    my $filter = '.foo';
    my ( $output, $stderr ) = capture { yq->main( $filter, $file ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'bar' ];
};

subtest 'multiple documents print properly' => sub {
    my $doc = <<ENDYML;
foo: bar
baz: buzz
ENDYML
    open my $stdin, '<', \$doc;
    local *STDIN = $stdin;
    my $filter = '.foo, .baz';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );
    cmp_deeply \@got, [ 'bar', 'buzz' ];
};

subtest 'finish() gets called' => sub {
    my $docs = <<ENDYML;
---
foo: 'bar'
baz: 1
---
foo: 'bar'
baz: 2
---
foo: 'baz'
baz: 3
ENDYML
    open my $stdin, '<', \$docs;
    local *STDIN = $stdin;
    my $filter = 'group_by( .foo )';
    my ( $output, $stderr ) = capture { yq->main( $filter ) };
    ok !$stderr, 'stderr is empty' or diag "STDERR: $stderr";
    my @got = YAML::Load( $output );

    cmp_deeply \@got, [
        {
            bar => [
                {
                    foo => 'bar',
                    baz => 1,
                },
                {
                    foo => 'bar',
                    baz => 2,
                },
            ],
            baz => [
                {
                    foo => 'baz',
                    baz => 3,
                },
            ],
        },
    ];
};

done_testing;
