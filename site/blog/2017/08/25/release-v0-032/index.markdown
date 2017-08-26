---
status: published
tags:
  - release
title: Release v0.032
---

In this release, we've added a command to read/write time series data:
`yts`. It only works with [InfluxDB](http://influxdata.com) for now, but
writing new interfaces to time series databases is easy!

Along with the new `ysql` `--count` option, it's easy to create metrics
from data in your database:

    # Count the number of test reports
    ysql cpantesters --count test_reports \
        | yts influxdb://localhost/telegraf cpantesters report_count

    # Count the number of processed reports
    ysql cpantesters --count cpanstats \
        | yts influxdb://localhost/telegraf cpantesters processed_count

    # Build metrics for Minion job worker
    ysql cpantesters --count minion_jobs \
        | yts influxdb://localhost/telegraf minion total_jobs
    ysql cpantesters --count minion_jobs --where 'status="inactive"' \
        | yts influxdb://localhost/telegraf minion inactive_jobs
    ysql cpantesters --count minion_jobs --where 'status="finished"' \
        | yts influxdb://localhost/telegraf minion finished_jobs

[More information about ETL-Yertl v0.032 on MetaCPAN](http://metacpan.org/release/PREACTION/ETL-Yertl-0.032)
