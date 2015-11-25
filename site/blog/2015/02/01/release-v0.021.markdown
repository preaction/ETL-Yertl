---
last_modified: 2015-02-01 23:20:52
tags: release
title: Release v0.021
---

A breaking change in this release: `ysql` no longer needs the word `query` to
run a query.  With the earlier removal of the `write` command, the `query`
command was the only way to run a query. Instead of requiring the additional
command, now we can save a little bit of typing.

This release has plenty of additions to the `ygrok` script, allowing it to
easily parse logs from Apache HTTPD and Syslog, the output of `ls -l` and `ps`.
There's also a new `-l` flag to allow loose matching of input lines.

This release also allows you to add your own `ygrok` patterns. In addition to
adding your own custom patterns, you can list all the existing patterns by
doing `ygrok --pattern`. See [the ygrok documentation](/pod/ygrok) for more
details.

With all the possibilities, `ygrok` patterns can now be organized into
namespaces. This will hopefully make it easier to manage as we add more
patterns to the Yertl core.

Full changelog below:

---

* [add --loose flag to ygrok to match partial lines](https://github.com/preaction/ETL-Yertl/commit/b1302b5d17781c6fe17fcd6b6ecccab4011b2409) ([#120](https://github.com/preaction/ETL-Yertl/issues/120))
* [add ygrok patterns for ps, ps u, and ps x](https://github.com/preaction/ETL-Yertl/commit/11e99aa926db9b1b4aa657940103e7371db86aa4)
* [add ygrok pattern for POSIX `ls -l`](https://github.com/preaction/ETL-Yertl/commit/d086c452ecaed0e281ad5fe89f8d6c8d5353d271) ([#116](https://github.com/preaction/ETL-Yertl/issues/116))
* [add ygrok to the main page synopsis](https://github.com/preaction/ETL-Yertl/commit/97369b3847b8cd66a677d0b3de1de1b88dd6e5e3) ([#112](https://github.com/preaction/ETL-Yertl/issues/112))
* [add syslog pattern to ygrok](https://github.com/preaction/ETL-Yertl/commit/eae9af551a6273579e13c6cb562e73c6ed95764f) ([#108](https://github.com/preaction/ETL-Yertl/issues/108))
* [allow adding, editing, and listing ygrok patterns](https://github.com/preaction/ETL-Yertl/commit/ab84ebb175099d1727ba3bd5c2cb09c075235c0e) ([#107](https://github.com/preaction/ETL-Yertl/issues/107))
* [fix multiply-nested patterns](https://github.com/preaction/ETL-Yertl/commit/e05f872c571cee75521e1fa1b52aee3b5c133d7b)
* [document all existing ygrok patterns](https://github.com/preaction/ETL-Yertl/commit/282433dba939c0f4f66e06888c59c370f1dc42ee) ([#111](https://github.com/preaction/ETL-Yertl/issues/111))
* [add pattern categories to ygrok](https://github.com/preaction/ETL-Yertl/commit/ca49f9b0e2951c90875bafc186ffe2bde9fc49ac) ([#109](https://github.com/preaction/ETL-Yertl/issues/109))
* [add ysql help guide](https://github.com/preaction/ETL-Yertl/commit/beab13b66ce946f638dece748127917718f278ef)
* [remove need for "query" when using ysql](https://github.com/preaction/ETL-Yertl/commit/970b3f477c2da5e201fd42f11b2dea04320b1170) ([#119](https://github.com/preaction/ETL-Yertl/issues/119))
* [add combined log format pattern for grok](https://github.com/preaction/ETL-Yertl/commit/e2d390c4fa8c25c055195ad4be3b4a980f102c0c)
* [allow recursive grok patterns](https://github.com/preaction/ETL-Yertl/commit/295305fb31e73584a7b0113494ace2ab63af571e)
* [add ygrok patterns to parse http common log format](https://github.com/preaction/ETL-Yertl/commit/ba5ba63f6a183845ab095d30b806be35c692b9b4)
* [fix warnings when an unknown grok pattern is used](https://github.com/preaction/ETL-Yertl/commit/f2b146afe89b725dfcaa3dec493f892d3e566c3f)
* [fix spurious contributor](https://github.com/preaction/ETL-Yertl/commit/aa22a8a0b876c2796e38de48570f034a36ec0413) ([#106](https://github.com/preaction/ETL-Yertl/issues/106))
