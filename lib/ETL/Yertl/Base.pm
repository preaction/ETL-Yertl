package ETL::Yertl::Base;
# ABSTRACT: Base module for ETL::Yertl

use strict;
use warnings;
use base 'Import::Base';

sub modules {
    my ( $class, %args ) = @_;
    return (
        strict => [],
        warnings => [],
        feature => [qw( :5.10 )],
    );
}

1;
