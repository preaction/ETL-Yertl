
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::json;

my $CLASS = 'ETL::Yertl::Format::json';

# 3-space indents because JSON::XS provides no other option
my $EXPECT_TO = <<ENDJSON;
{
   "baz" : "buzz",
   "foo" : "bar"
}
{
   "flip" : [
      "flop",
      "blip"
   ]
}
[
   "foo",
   "bar",
   "baz"
]
ENDJSON

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
        } qr{format_module must be one of: JSON::XS JSON::PP};
    };
};

subtest 'JSON::XS' => sub {
    my $formatter = $CLASS->new( format_module => 'JSON::XS' );
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'JSON::PP' => sub {
    my $formatter = $CLASS->new( format_module => 'JSON::PP' );
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'default' => sub {
    my $formatter = $CLASS->new;
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'no formatter available' => sub {
    local @ETL::Yertl::Format::json::FORMAT_MODULES = (
        'Not::JSON::Module' => 0,
        'Not::Other::Module' => 0,
        'LowVersion' => 1,
    );
    throws_ok {
        $CLASS->new->format_module;
    } qr{Could not load a formatter for JSON[.] Please install one of the following modules:};
    like $@, qr{Not::JSON::Module \(Any version\)};
    like $@, qr{Not::Other::Module \(Any version\)};
    like $@, qr{LowVersion \(version 1\)};
};

done_testing;
