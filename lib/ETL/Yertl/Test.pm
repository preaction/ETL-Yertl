package ETL::Yertl::Test;
# ABSTRACT: Base module for ETL::Yertl tests

use strict;
use warnings;
use base 'ETL::Yertl::Base';

sub modules {
    my ( $class, %args ) = @_;
    my @modules = $class->SUPER::modules( %args );
    return (
        @modules,
        qw( Test::More Test::Deep Test::Exception Test::Differences ),
        FindBin => [ '$Bin' ],
        boolean => [':all'],
    );
}

1;
