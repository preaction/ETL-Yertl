---
tags:
  - release
title: Release v0.024
---

A small release to fix the `ps` grok patterns for GNU procutils and to add
the `yq -x` option to make it a lot easier to pipe the output of yq into
another program.

Full changelog below

---

* [add xargs mode to yq](https://github.com/preaction/Statocles/commit/3eb42192089b91e545ac57dbc0aa76b84d0f1b28) ([#52](https://github.com/preaction/Statocles/issues/52))
* [remove ModuleBuild to prevent toolchain confusion](https://github.com/preaction/Statocles/commit/eb41b737f2f14dcaf5f0058be4e0528c75f0dc2f)
* [fix ps grok patterns to work on RHEL 5](https://github.com/preaction/Statocles/commit/8295b200d38d5fc01c30afc5bc785405684db010) ([#127](https://github.com/preaction/Statocles/issues/127))
