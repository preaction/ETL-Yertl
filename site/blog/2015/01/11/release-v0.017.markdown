---
author: preaction
last_modified: 2015-01-11 23:33:47
tags: release
title: Release v0.017
---

This release fixes a bunch of issues with `ysql`, and allows displaying of database
configuration.

Full changelog below:

---

* [remove docs about trim option](https://github.com/preaction/Statocles/commit/bec7ae0df7a91d8c8b285e26209692aa5212fa9d)
* [add validation for database driver](https://github.com/preaction/Statocles/commit/2cac631f018e2ba12efeeb712f24d7ec017753d8) ([#76](https://github.com/preaction/Statocles/issues/76))
* [add drivers ysql command to list database drivers](https://github.com/preaction/Statocles/commit/62a9176890b641d26ec843bb157304e7b2476bf5) ([#75](https://github.com/preaction/Statocles/issues/75))
* [document new ysql config read commands](https://github.com/preaction/Statocles/commit/2b801e0238f510df3c4849f47620cf9d8d9ee571)
* [show error if a database key does not exist](https://github.com/preaction/Statocles/commit/b0552cc674de31341dfe0d2da9643d4bfce6a689) ([#74](https://github.com/preaction/Statocles/issues/74))
* [add read config commands to ysql](https://github.com/preaction/Statocles/commit/90850e278ff311233a7ade276b7b60b2c2381767) ([#73](https://github.com/preaction/Statocles/issues/73))
* [add documentation for ymask](https://github.com/preaction/Statocles/commit/0b9a46c2d14cc0fc7fa5c9fb5affb93bf859cf64) ([#53](https://github.com/preaction/Statocles/issues/53))
* [make DBI completely optional](https://github.com/preaction/Statocles/commit/cb42b499ef1755eb8798a37c7d757c24e1f8c53b) ([#77](https://github.com/preaction/Statocles/issues/77))
* [add cookbook with embedded json recipe](https://github.com/preaction/Statocles/commit/aff2829abd5c7d6c328fc8c737a7164b0735c5c1) ([#82](https://github.com/preaction/Statocles/issues/82))
