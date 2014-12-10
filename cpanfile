requires "Data::Partial::Google" => "0";
requires "File::Spec" => "0";
requires "Getopt::Long" => "2.36";
requires "Import::Base" => "0";
requires "Module::Runtime" => "0";
requires "Parse::RecDescent" => "0";
requires "Pod::Usage::Return" => "0";
requires "Regexp::Common" => "0";
requires "YAML" => "0";
requires "boolean" => "0";
requires "perl" => "5.010";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "Capture::Tiny" => "0";
  requires "Test::Compile" => "0";
  requires "Test::Deep" => "0";
  requires "Test::Differences" => "0";
  requires "Test::Exception" => "0";
  requires "Test::More" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};
