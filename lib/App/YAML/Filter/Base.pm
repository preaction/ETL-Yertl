package App::YAML::Filter::Base;
# ABSTRACT: Base module for App::YAML::Filter

use strict;
use warnings;
use base 'Import::Base';

sub modules {
    my ( $class, %args ) = @_;
    return (
        strict => [],
        warnings => [],
    );
}

1;
