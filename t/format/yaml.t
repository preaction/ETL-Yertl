
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::yaml;
use List::Util qw( pairkeys );

my @FORMATTER_MODULES;
BEGIN {
    @FORMATTER_MODULES = grep { eval "use $_; 1" } pairkeys @ETL::Yertl::Format::yaml::FORMAT_MODULES;
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

subtest 'constructor' => sub {
    subtest 'invalid format module' => sub {
        throws_ok {
            $CLASS->new( format_module => 'Not::Supported' );
        } qr{format_module must be one of: YAML::XS YAML::Syck YAML};
        unlike $@, qr{yaml[.]pm line \d+}, 'does not contain module/line';
    };
};

subtest 'default formatter' => sub {
    subtest 'input' => sub {
        my $formatter = $CLASS->new( input => $EXPECT_TO->openr );
        my $got = [ $formatter->read ];
        cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
    };

    subtest 'output' => sub {
        my $formatter = $CLASS->new;
        my $got_yaml = $formatter->write( @EXPECT_FROM );
        my $format_module = $formatter->format_module;

        no strict 'refs';
        cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;
    };
};

subtest 'formatter modules' => sub {
    for my $format_module ( @FORMATTER_MODULES ) {
        subtest $format_module => sub {
            subtest 'input' => sub {
                my $formatter = $CLASS->new( input => $EXPECT_TO->openr );
                my $got = [ $formatter->read ];
                cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
            };

            subtest 'output' => sub {
                my $formatter = $CLASS->new( format_module => $format_module );
                # Can't compare against strings because whitespace is both significant
                # and differs between implementations
                # And YAML::XS and YAML are _incompatible_. See: https://github.com/ingydotnet/yaml-libyaml-pm/issues/9
                my $got_yaml = $formatter->write( @EXPECT_FROM );
                no strict 'refs';
                cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;
            };

            subtest 'decode' => sub {
                my $formatter = $CLASS->new( format_module => $format_module );
                my $given = $formatter->write( $EXPECT_FROM[0] );
                cmp_deeply $formatter->decode( $given ), $EXPECT_FROM[0];
            };

            subtest 'empty file' => sub {
                my $tmp = tempfile;
                my $formatter = $CLASS->new( input => $tmp->openr );
                my $got;
                lives_ok { $got = [ $formatter->read ] };
                cmp_deeply $got, [], 'file is empty';
            };

        };
    }
};

subtest 'no formatter available' => sub {
    local @ETL::Yertl::Format::yaml::FORMAT_MODULES = (
        'Not::YAML::Module' => 0,
        'Not::Other::Module' => 0,
        'LowVersion' => 1,
    );
    throws_ok {
        $CLASS->new->format_module;
    } qr{Could not load a formatter for YAML[.] Please install one of the following modules:};
    like $@, qr{Not::YAML::Module \(Any version\)};
    like $@, qr{Not::Other::Module \(Any version\)};
    like $@, qr{LowVersion \(version 1\)};
    unlike $@, qr{yaml[.]pm line \d+}, 'does not contain module/line';
};

done_testing;
