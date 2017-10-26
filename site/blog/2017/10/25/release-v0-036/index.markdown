---
tags: release
title: Release v0.036
---

In this release:

## Added

* Added `parse_time` function to `yq`. This function parses a date/time
  string into a UNIX epoch.
* Added epoch timestamps as an allowed format for `yts` time series
  timestamps.
* Add default timestamps of "now" in `yts`. This makes all time series
  databases the same and makes it easier to add metrics.
* Added 'LINUX.PROC.LOADAVG' and 'LINUX.PROC.UPTIME' patterns to `ygrok`
  to parse the `/proc/loadavg` and `/proc/uptime` files on Linux
  systems.

## Fixed

* Reduced version requirement for List::Util. This continues our quest
  to be installable on a core Perl 5.10 without a compiler.
* Removed unused prereq (Text::Trim).

## Removed

* Removed the `ymask` command and associated prereqs. This command just
  wasn't very useful, and depended on a module that requires a compiler.

[More information about ETL-Yertl v0.036 on
MetaCPAN](http://metacpan.org/release/PREACTION/ETL-Yertl-0.036)
