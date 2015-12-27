
use ETL::Yertl 'Test';
use Test::Lib;
use ETL::Yertl::Format::default;

subtest 'default default is yaml' => sub {
    my $formatter = ETL::Yertl::Format::default->new;
    isa_ok $formatter, 'ETL::Yertl::Format::yaml';
};

subtest 'set default to json' => sub {
    local $ENV{YERTL_FORMAT} = 'json';
    my $formatter = ETL::Yertl::Format::default->new;
    isa_ok $formatter, 'ETL::Yertl::Format::json';
};

done_testing;
