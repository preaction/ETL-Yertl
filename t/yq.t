
use App::YAML::Filter::Base;
use Test::Most;
use YAML qw( Dump Load );
use Capture::Tiny qw( capture );
use FindBin qw( $Bin );
use File::Spec;

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
    my $filter = '.foo, .baz';
    my @out = yq->filter( $filter, $doc );
    cmp_deeply \@out, [ 'bar', 'fuzz' ];
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

    $filter = 'if .foo eq buzz then .foo else .baz';
    $out = yq->filter( $filter, $doc );
    cmp_deeply $out, $doc->{baz};
};

subtest 'empty' => sub {
    my $filter = 'empty';
    my $out = yq->filter( $filter, { foo => 'bar' } );
    isa_ok $out, 'empty';
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

done_testing;
