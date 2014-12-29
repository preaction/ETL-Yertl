requires "Data::Partial::Google" => "0";
requires "File::Spec" => "0";
requires "Getopt::Long" => "2.36";
requires "Import::Base" => "0";
requires "List::Util" => "1.29";
requires "Module::Runtime" => "0";
requires "Moo::Lax" => "0";
requires "Parse::RecDescent" => "0";
requires "Path::Tiny" => "0";
requires "Pod::Usage::Return" => "0";
requires "Regexp::Common" => "0";
requires "Text::Trim" => "0";
requires "Type::Tiny" => "0";
requires "Types::Standard" => "0";
requires "YAML" => "0";
requires "boolean" => "0";
requires "perl" => "5.010";
recommends "JSON::PP" => "0";
recommends "JSON::XS" => "0";
recommends "Text::CSV" => "0";
recommends "Text::CSV_XS" => "0";
recommends "YAML::Syck" => "0";
recommends "YAML::XS" => "0";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'test' => sub {
  requires "Capture::Tiny" => "0";
  requires "Dir::Self" => "0";
  requires "JSON::PP" => "0";
  requires "Test::Compile" => "0";
  requires "Test::Deep" => "0";
  requires "Test::Differences" => "0";
  requires "Test::Exception" => "0";
  requires "Test::Lib" => "0";
  requires "Test::More" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};
