---
last_modified: 2015-01-21 22:06:32
tags: release
title: Release v0.019
---

This release fixes a few bugs and inconsistencies in the `ysql` command, in
anticipation of a blog post explaining how it works.

We removed the "write" command in favor of making the "query" command accept
input on `STDIN` and handle placeholders. So now you can run "SELECT" queries
for each document as it comes in, perhaps to look up users as something
else write's YAML with their ID in it.

Full changelog below:

---

* [add missing ABSTRACTs to Command modules](https://github.com/preaction/Statocles/commit/f8c9a102a691037659ad5a89fe615f076d7984fc)
* [add error checking when preparing or executing SQL](https://github.com/preaction/Statocles/commit/5a2783d5fafa6473bf422308cec6763c7375902d) ([#92](https://github.com/preaction/Statocles/issues/92))
* [allow using "--dsn" to edit config](https://github.com/preaction/Statocles/commit/749060f26b576947ad290a8b9ec8683637f16165) ([#91](https://github.com/preaction/Statocles/issues/91))
* [combine write and query in ysql](https://github.com/preaction/Statocles/commit/9ff860bb6a96d963a11e1126fe364fd8bf158900)
* [fix test failure on DBD::SQLite 1.33](https://github.com/preaction/Statocles/commit/42845367e54f3402fcb61de91c8b6d681e6fb7ec) ([#86](https://github.com/preaction/Statocles/issues/86))
