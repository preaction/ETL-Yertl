
=head1 DESCRIPTION

This tests the base L<ETL::Yertl::Format> module, which is used to instantiate
specific formatters by name.

=cut

use ETL::Yertl 'Test';
use ETL::Yertl::Format;

subtest 'get_default' => sub {
    my $format = ETL::Yertl::Format->get( 'json' );
    isa_ok $format, 'ETL::Yertl::Format::json', 'get( "json" )';
};

subtest 'get_default' => sub {
    local $ENV{YERTL_FORMAT} = 'json';
    my $format = ETL::Yertl::Format->get_default;
    isa_ok $format, 'ETL::Yertl::Format::json', 'get_default with YERTL_FORMAT="json"';
};

done_testing;
