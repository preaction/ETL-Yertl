---
tags: release
title: Release v0.027
---

Only some minor fixes, but one bugfix that could cause the test to fail.

* Updated the version of Path::Tiny we rely on to fix a potential test
  failure.
* Add the `--delete <table>` option to [the ysql utility](/pod/ysql).
  This allows you to delete from a table, optionally adding a where
  clause option (`--where <clause>`).
* Add IPv4 and IPv6 patterns to [the ygrok utility](/pod/ygrok). These
  were already provided by [the Regexp::Common
  module](http://metacpan.org/pod/Regexp::Common), so best to use the
  tested regular expressions

Full changelog below.

---

* [use ipv4 and ipv6 patterns from Regexp::Common](https://github.com/preaction/ETL-Yertl/commit/0e2d7f60d7f3994945654df6852708b085aed8b5)
* [update Path::Tiny version to fix File::Path issue](https://github.com/preaction/ETL-Yertl/commit/f2b55f5560483161417cab514d844b1fb86f87d6) ([#137](https://github.com/preaction/ETL-Yertl/issues/137))
* [expand sql helpers docs to link related helpers](https://github.com/preaction/ETL-Yertl/commit/29003751b447d663bcc2f7dc800e25ff141b4580) ([#136](https://github.com/preaction/ETL-Yertl/issues/136))
* [add the --delete helper option to ysql](https://github.com/preaction/ETL-Yertl/commit/1f6597d9640463e2b613b560f2c57e5317b77f2a) ([#136](https://github.com/preaction/ETL-Yertl/issues/136))
