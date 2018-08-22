
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::json;

my @FORMATTER_MODULES;
BEGIN {
    @FORMATTER_MODULES = grep { eval "use $_; 1" }
        map { $_->[0] } ETL::Yertl::Format::json::_formatter_classes();
    plan skip_all => 'No formatter modules available (tried ' . join( ", ", @FORMATTER_MODULES ) . ')'
        unless @FORMATTER_MODULES;
}

my $SHARE_DIR = path( __DIR__, '..', 'share' );
my $CLASS = 'ETL::Yertl::Format::json';
my $EXPECT_TO = $SHARE_DIR->child( json => 'test.json' );

my @EXPECT_FROM = (
    {
        foo => 'bar',
        baz => 'buzz',
    },
    {
        flip => [qw( flop blip )],
    },
    [qw( foo bar baz )],
);

subtest 'default formatter class' => sub {
    subtest 'read_buffer' => sub {
        my $formatter = $CLASS->new;
        my $given = $formatter->format( $EXPECT_FROM[0] );
        cmp_deeply $formatter->read_buffer( \$given ), $EXPECT_FROM[0];
    };

    subtest 'format' => sub {
        my $formatter = $CLASS->new;
        eq_or_diff join( "", map { $formatter->format( $_ ) } @EXPECT_FROM ), $EXPECT_TO->slurp;
    };
};

subtest 'formatter modules' => sub {
    for my $formatter_module ( @FORMATTER_MODULES ) {
        subtest $formatter_module => sub {
            subtest 'read_buffer' => sub {
                my $formatter = $CLASS->new( formatter_class => $formatter_module );
                my $given = $formatter->format( $EXPECT_FROM[0] );
                cmp_deeply $formatter->read_buffer( \$given ), $EXPECT_FROM[0];
            };

            subtest 'format' => sub {
                my $formatter = $CLASS->new( formatter_class => $formatter_module );
                eq_or_diff join( "", map { $formatter->format( $_ ) } @EXPECT_FROM ), $EXPECT_TO->slurp;
            };
        };
    }
};

done_testing;
