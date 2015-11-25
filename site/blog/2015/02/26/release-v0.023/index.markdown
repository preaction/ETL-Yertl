---
last_modified: 2015-02-26 12:43:58
tags: release
title: Release v0.023
---

A quick release to fix a bug in `yq` that would cause a confusing error. Since `yq`
was using YAML exclusively, but other commands were using other YAML modules, there
was a possibility for one command to write output that another command could not
parse.

Now this is fixed and `yq` uses the same formatting routines as everything else.

Full changelog below:

---

* [make yq use formatter modules](https://github.com/preaction/ETL-Yertl/commit/966c355fa059af8b3b23fcfaf7ec6034b19534c1)
