package App::YAML::Filter::Test;
# ABSTRACT: Base module for App::YAML::Filter tests

use strict;
use warnings;
use base 'App::YAML::Filter::Base';

sub modules {
    my ( $class, %args ) = @_;
    my @modules = $class->SUPER::modules( %args );
    return (
        @modules,
        FindBin => [ '$Bin' ],
        'Test::Most' => [],
        boolean => [':all'],
    );
}

1;
