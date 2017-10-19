---
tags: release
title: Release v0.035
---

In this release:

[More information about ETL-Yertl v0.035 on MetaCPAN](http://metacpan.org/release/PREACTION/ETL-Yertl-0.035)

## Added

* Added Graphite time series adapter. Now `yts` can read/write time
  series from the Graphite system and related subsystems. The write
  function is compatible with the "line" protocol, so any databases that
  understand Graphite's line protocol can be written to.

* Added --start and --end options to `yts` command to constrain the time
  series returned to a specific date/time range.

## Fixed

* Removed 'Z' time zone indicator from `yts` input/output and time series
  adapters. Time zone does not enter in to any of the things we're doing
  with time series. If users need to do things with time zones, they'll
  have to do it themselves (poor souls).

* Fixed a race condition that could cause `yts` to read the data and not
  write the data passed-in on `STDIN`. This requires a new dependency,
  IO::Interactive.

* Removed dependencies on some modules to reduce the memory footprint
  and improve startup times:

    * DateTime
    * Moo
    * Type::Tiny

* Removed some unused modules that are not going to be developed
  anymore.

    * Parse::RecDescent versions of the `yq` language parser. Perl 5.10
      regex grammars work just fine.

* Fixed YAML.pm (YAML::Old) causing tests to fail. This has been removed
  (for now) as a supported YAML module. The default supported YAML
  module is now YAML::Tiny.

* Fixed the `yts` time series format. Now there is only the "metric" to
  identify the time series, which for some time series databases may
  contain abstractions like "database" and "column".

* Fixed nulls appearing in Graphite time series.
