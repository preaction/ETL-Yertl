---
last_modified: 2015-02-01 23:01:43
tags: release
title: Release v0.020
---

This release adds the first initial development of `ygrok`, the Yertl program
for parsing lines of plain text input into documents.

`ygrok` is perfect for parsing log files and command output.  By using simple
patterns or named regex captures, we can parse a line of input into a document,
which we can then write to a database using `ysql`, or convert to CSV or JSON
with `yto`.

Lots more development on `ygrok` to come!

Full changelog below:

---

* [add short descriptions of all the Yertl tools](https://github.com/preaction/ETL-Yertl/commit/43ae7601fe059316e08da0c0736220435f6f8cb4)
* [add ysql to main page synopsis](https://github.com/preaction/ETL-Yertl/commit/60b11d2bbcf0d3a27f3ee4bf0159307188ace100) ([#98](https://github.com/preaction/ETL-Yertl/issues/98))
* [add links to yertl homepage](https://github.com/preaction/ETL-Yertl/commit/11f5d1def364c186f4f65d8b71eff7b087b7c8d1) ([#99](https://github.com/preaction/ETL-Yertl/issues/99))
* [exclude the website from the cpan dist](https://github.com/preaction/ETL-Yertl/commit/75abbd5884a52f2d71ad6db8c77928817da76435) ([#104](https://github.com/preaction/ETL-Yertl/issues/104))
* [fix "prototype mismatch" from Parse::RecDescent](https://github.com/preaction/ETL-Yertl/commit/e1da406e1ec7b166764bed9099c5385291b7d406) ([#103](https://github.com/preaction/ETL-Yertl/issues/103))
* [add initial ygrok script](https://github.com/preaction/ETL-Yertl/commit/af37bfa9e7b28df47b15a431717c74f0b446fdb5) ([#105](https://github.com/preaction/ETL-Yertl/issues/105))
* [add dzil plugin for prereqs and compile tests](https://github.com/preaction/ETL-Yertl/commit/b18fcb7d80e657151dfa90ebac647cf5de64bd93)
