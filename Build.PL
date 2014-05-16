
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => "6.30",
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Filter YAML through a command-line program",
  "dist_author" => [
    "Doug Bell <preaction\@cpan.org>"
  ],
  "dist_name" => "App-YAML-Filter",
  "dist_version" => "0.010",
  "license" => "perl",
  "module_name" => "App::YAML::Filter",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "File::Spec" => 0,
    "Getopt::Long" => "2.36",
    "Import::Base" => 0,
    "Pod::Usage::Return" => 0,
    "Text::Balanced" => 0,
    "YAML" => 0,
    "boolean" => 0,
    "perl" => "5.010"
  },
  "script_files" => [
    "bin/yq"
  ],
  "test_requires" => {
    "Capture::Tiny" => 0,
    "Test::Compile" => 0,
    "Test::Most" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
