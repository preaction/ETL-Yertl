
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::csv;
my $SHARE_DIR = path( __DIR__, '..', 'share' );

my $CLASS = 'ETL::Yertl::Format::csv';

my $EXPECT_TO = $SHARE_DIR->child( csv => 'test.csv' );

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

subtest 'constructor' => sub {
    subtest 'invalid format module' => sub {
        throws_ok {
            $CLASS->new( format_module => 'Not::Supported' );
        } qr{format_module must be one of: Text::CSV_XS Text::CSV};
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
        eq_or_diff $formatter->write( @EXPECT_FROM ), $EXPECT_TO->slurp;
    };
};

subtest 'formatter modules' => sub {
    subtest 'Text::CSV_XS' => sub {
        subtest 'input' => sub {
            my $formatter = $CLASS->new(
                input => $EXPECT_TO->openr,
                format_module => 'Text::CSV_XS',
            );
            my $got = [ $formatter->read ];
            cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
        };

        subtest 'output' => sub {
            my $formatter = $CLASS->new( format_module => 'Text::CSV_XS' );
            eq_or_diff $formatter->write( @EXPECT_FROM ), $EXPECT_TO->slurp;
        };
    };

    subtest 'Text::CSV' => sub {
        subtest 'input' => sub {
            my $formatter = $CLASS->new(
                input => $EXPECT_TO->openr,
                format_module => 'Text::CSV',
            );
            my $got = [ $formatter->read ];
            cmp_deeply $got, \@EXPECT_FROM or diag explain $got;
        };

        subtest 'output' => sub {
            my $formatter = $CLASS->new( format_module => 'Text::CSV' );
            eq_or_diff $formatter->write( @EXPECT_FROM ), $EXPECT_TO->slurp;
        };
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
