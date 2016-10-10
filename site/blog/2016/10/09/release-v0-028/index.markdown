---
tags: release
title: Release v0.028
---

These changes have been pending for quite a while, but they're finally
here! Though it may not show, I actually love this project, and every
excuse someone gives me to work on it I take with both hands.

In this release:

## Added

* The YAML::Tiny module is now officially supported
* The YERTL_FORMAT environment variable will set the default format
  that Yertl uses to communicate. Set it to `json` for Yertl to
  seamlessly interoperate with other JSON-based tools like `jq` and
  `recs`.
* CSV conversion (`yto`/`yfrom`) now allows setting a delimiter so
  we can parse colon-separated values or esoteric formats

## Fixed

* `yq -x` now checks for definedness before trying to print. This
  silences warnings from Perl about "Uninitialized value in print".
  In the future, we may re-enable warnings through a `-w` or `-v`
  switch.
* If one filter in a pipe returns empty, that empty result is
  propagated through further filters. This makes the output of
  something like `select( .foo == 1 ) | .bar` more intuitive: If
  a document doesn't pass the first part, the result of the second
  part is `empty`, not `undef` (`--- ~`).
* The `ysql` helpers and placeholders are now better documented in
  the ysql guide.

## Other

* ygrok tests are now split into more maintainable chunks based on
  the patterns they are testing.
