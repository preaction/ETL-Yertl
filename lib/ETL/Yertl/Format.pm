package ETL::Yertl::Format;
our $VERSION = '0.034';
# ABSTRACT: Base class for input/output formats

use ETL::Yertl;
sub new {
    my ( $class, %args ) = @_;
    return bless \%args, $class;
}

1;
