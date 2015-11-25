---
tags:
  - release
title: Release v0.025
---

Some minor bugfixes in this release. One that would make Yertl
fail its tests (and therefore fail to install). Two that caused some
very confusing error messages to be printed when using
[ysql](/pod/ysql.html). And a final one that made it hard to use the
HTTP log pattern with [ygrok](/pod/ygrok.html).

Full changelog below...

---

* [fix SQL error using --dsn printing error twice](https://github.com/preaction/ETL-Yertl/commit/72ddcae4449deb0eac3aa38b59eee6d9195e82dc)
* [handle error in connect with useful error message](https://github.com/preaction/ETL-Yertl/commit/0218234274315114acda42691ce81012f787bab6) ([#131](https://github.com/preaction/ETL-Yertl/issues/131))
* [update Regexp::Common to 2013031301](https://github.com/preaction/ETL-Yertl/commit/1fe4dce56b49c2675745701dd10d42e4b1e0375c) ([#124](https://github.com/preaction/ETL-Yertl/issues/124))
* [make http log patterns more lenient](https://github.com/preaction/ETL-Yertl/commit/29dded382f2a410b0cd036c0b78c513fc8111de1) ([#129](https://github.com/preaction/ETL-Yertl/issues/129))
