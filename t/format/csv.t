
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::csv;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $CLASS = 'ETL::Yertl::Format::csv';

my $EXPECT_TO = $SHARE_DIR->child( csv => 'test.csv' )->slurp;
my $EXPECT_TO_NOTRIM = $SHARE_DIR->child( csv => 'notrim.csv' )->slurp;

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

my @EXPECT_FROM_NOTRIM = (
    {
        bar => '  2',
        baz => '  3',
        foo => 'one',
    },
    {
        bar => '  4',
        baz => '  5',
        foo => 'two',
    },
);

subtest 'constructor' => sub {
    subtest 'invalid format module' => sub {
        throws_ok {
            $CLASS->new( format_module => 'Not::Supported' );
        } qr{format_module must be one of: Text::CSV_XS Text::CSV};
    };
};

subtest 'Text::CSV_XS' => sub {
    my $formatter = $CLASS->new( format_module => 'Text::CSV_XS' );
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( split /\n/, $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'Text::CSV' => sub {
    my $formatter = $CLASS->new( format_module => 'Text::CSV' );
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( split /\n/, $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'default' => sub {
    my $formatter = $CLASS->new;
    eq_or_diff $formatter->to( @EXPECT_FROM ), $EXPECT_TO;
    my $got = [ $formatter->from( split /\n/, $EXPECT_TO ) ];
    cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
};

subtest 'format options' => sub {

    subtest 'trim (default)' => sub {
        my $formatter = $CLASS->new;
        my $got = [ $formatter->from( split /\n/, $EXPECT_TO_NOTRIM ) ];
        cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
    };

    subtest 'no trim' => sub {
        my $formatter = $CLASS->new( trim => 0 );
        my $got = [ $formatter->from( split /\n/, $EXPECT_TO_NOTRIM ) ];
        cmp_deeply $got, \@EXPECT_FROM_NOTRIM or diag explain $got;
    };

};

subtest 'no formatter available' => sub {
    local @ETL::Yertl::Format::csv::FORMAT_MODULES = (
        'Not::CSV::Module' => 0,
        'Not::Other::Module' => 0,
        'LowVersion' => 1,
    );
    throws_ok {
        $CLASS->new->format_module;
    } qr{Could not load a formatter for CSV[.] Please install one of the following modules:};
    like $@, qr{Not::CSV::Module \(Any version\)};
    like $@, qr{Not::Other::Module \(Any version\)};
    like $@, qr{LowVersion \(version 1\)};
};

done_testing;
