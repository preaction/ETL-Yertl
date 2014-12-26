
use ETL::Yertl 'Test';
use Test::Lib;
use YAML;
use ETL::Yertl::Format::yaml;

my $CLASS = 'ETL::Yertl::Format::yaml';

my $EXPECT_TO = <<ENDYAML;
---
baz: buzz
foo: bar
---
flip:
  - flop
  - blip
---
- foo
- bar
- baz
ENDYAML

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
    };
};

for my $format_module ( qw( YAML::XS YAML::Syck YAML ) ) {
    subtest $format_module => sub {
        my $formatter = $CLASS->new( format_module => $format_module );
        # Can't compare against strings because whitespace is both significant
        # and differs between implementations
        # And YAML::XS and YAML are _incompatible_. See: https://github.com/ingydotnet/yaml-libyaml-pm/issues/9
        my $got_yaml = $formatter->to( @EXPECT_FROM );
        no strict 'refs';
        cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;

        my $got = [ $formatter->from( $EXPECT_TO ) ];
        cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
    };
}

subtest 'default' => sub {
    my $formatter = $CLASS->new;
    my $got_yaml = $formatter->to( @EXPECT_FROM );
    my $format_module = $formatter->format_module;

    no strict 'refs';
    cmp_deeply [ "${format_module}::Load"->( $got_yaml ) ], \@EXPECT_FROM or diag $got_yaml;

    my $got = [ $formatter->from( $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
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
};

done_testing;
