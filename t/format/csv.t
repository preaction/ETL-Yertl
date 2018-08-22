
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::csv;

my @FORMATTER_MODULES;
BEGIN {
    @FORMATTER_MODULES = grep { eval "use $_; 1" }
        map { $_->[0] } ETL::Yertl::Format::csv::_formatter_classes();
    plan skip_all => 'No formatter modules available (tried ' . join( ", ", @FORMATTER_MODULES ) . ')'
        unless @FORMATTER_MODULES;
}

my $SHARE_DIR = path( __DIR__, '..', 'share' );
my $CLASS = 'ETL::Yertl::Format::csv';
my $EXPECT_TO = $SHARE_DIR->child( csv => 'test.csv' );
my $EXPECT_COLON = $SHARE_DIR->child( csv => 'test-colon.csv' );

my @EXPECT_FROM = (
    {
        bar => 2,
        baz => 3,
        foo => 'one',
    },
    {
        bar => 4,
        baz => 5,
        foo => 'two',
    },
);

subtest 'default formatter' => sub {
    subtest 'read_buffer' => sub {
        my $formatter = $CLASS->new;
        my $given = join "", map { $formatter->format( $_ ) } @EXPECT_FROM;
        $formatter = $CLASS->new;
        cmp_deeply [ $formatter->read_buffer( \$given ) ], \@EXPECT_FROM;
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
                my $given = join "", map { $formatter->format( $_ ) } @EXPECT_FROM;
                $formatter = $CLASS->new( formatter_class => $formatter_module );
                cmp_deeply [ $formatter->read_buffer( \$given ) ], \@EXPECT_FROM;
            };

            subtest 'format' => sub {
                my $formatter = $CLASS->new( formatter_class => $formatter_module );
                eq_or_diff join( "", map { $formatter->format( $_ ) } @EXPECT_FROM ), $EXPECT_TO->slurp;
            };

            subtest 'delimiter ":"' => sub {
                subtest 'read_buffer' => sub {
                    my $formatter = $CLASS->new(
                        formatter_class => $formatter_module,
                        delimiter => ":",
                    );
                    my $given = join "", map { $formatter->format( $_ ) } @EXPECT_FROM;
                    $formatter = $CLASS->new(
                        formatter_class => $formatter_module,
                        delimiter => ":",
                    );
                    cmp_deeply [ $formatter->read_buffer( \$given ) ], \@EXPECT_FROM;
                };

                subtest 'format' => sub {
                    my $formatter = $CLASS->new(
                        formatter_class => $formatter_module,
                        delimiter => ":",
                    );
                    eq_or_diff join( "", map { $formatter->format( $_ ) } @EXPECT_FROM ), $EXPECT_COLON->slurp;
                };
            };

        };
    }
};

done_testing;
