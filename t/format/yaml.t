
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::yaml;

my @FORMATTER_MODULES;
BEGIN {
    @FORMATTER_MODULES = grep { eval "use $_; 1" }
        map { $_->[0] } ETL::Yertl::Format::yaml::_formatter_classes();
    plan skip_all => 'No formatter modules available (tried ' . join( ", ", @FORMATTER_MODULES ) . ')'
        unless @FORMATTER_MODULES;
}

my $SHARE_DIR = path( __DIR__, '..', 'share' );
my $CLASS = 'ETL::Yertl::Format::yaml';
my $EXPECT_TO = $SHARE_DIR->child( yaml => 'test.yaml' );

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

subtest 'default formatter' => sub {
    subtest 'read_buffer' => sub {
        my $formatter = $CLASS->new;
        my $given = $formatter->format( $EXPECT_FROM[0] );
        cmp_deeply $formatter->read_buffer( \$given ), $EXPECT_FROM[0];
    };

    subtest 'output' => sub {
        my $formatter = $CLASS->new;
        my $got_yaml = join( "", map { $formatter->format( $_ ) } @EXPECT_FROM );
        my $format_module = $formatter->{formatter_class};

        no strict 'refs';
        cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;
    };
};

subtest 'formatter modules' => sub {
    for my $format_module ( @FORMATTER_MODULES ) {
        subtest $format_module => sub {
            subtest 'read_buffer' => sub {
                my $formatter = $CLASS->new( formatter_class => $format_module );
                my $given = $formatter->format( $EXPECT_FROM[0] );
                cmp_deeply $formatter->read_buffer( \$given ), $EXPECT_FROM[0];
            };

            subtest 'output' => sub {
                my $formatter = $CLASS->new( formatter_class => $format_module );
                my $got_yaml = join( "", map { $formatter->format( $_ ) } @EXPECT_FROM );
                my $format_module = $formatter->{formatter_class};

                no strict 'refs';
                cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;
            };
        };
    }
};

done_testing;
