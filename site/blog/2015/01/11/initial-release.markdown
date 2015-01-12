---
author: preaction
last_modified: 2015-01-11 21:47:13
tags: release
title: Initial Release
---
This is the first release with Yertl's new website! Yertl is an ETL (Extract,
Transform, Load) for the shell, with tools designed to be quickly assembled
together into useful ETL processes.

This release includes:

* Convert to and from YAML, JSON, and CSV (yto and yfrom)
* Read/write to/from SQL databases (ysql)
* Simple mask-style filtering (ymask)
* The beginning of a rich transform language (yq)

Future plans include:

* Job distribution using ZeroMQ send/receive
* Perl API for adding Yertl workflows to larger Perl scripts
* API for ORMs (DBIx::Class)
* API for document and key/value stores (MongoDB, Redis, Memcached)
* API for downloading and scraping data from websites (curl, Web::Query, Mojo::DOM)
* More options for filtering and transforming data (LINQ, XPath)

See [the Github feature tickets](https://github.com/preaction/ETL-Yertl/labels/feature)
for more future plans.
