package YAML::Filter::Base;
# ABSTRACT: Base module for YAML::Filter

use strict;
use warnings;
use Import::Into;
use Module::Runtime qw( use_module );

sub modules {
    my ( $class, %args ) = @_;
    my %modules = (
        strict => [],
        warnings => [],
    );
    return %modules;
}

sub import {
    my ( $class, %args ) = @_;
    my $caller = caller;
    my %modules = $class->modules( %args );
    for my $mod ( keys %modules ) {
        use_module( $mod )->import::into( $caller, @{ $modules{$mod} } );
    }
}

1;
