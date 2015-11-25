---
tags: release
title: Release v0.026
---

This release adds some SQL helper options to [the ysql
command](/pod/ysql):

* `--select <table>` creates a simple `SELECT * FROM <table>` query
* Add `--where <clause>` and `--order-by <clause>` to modify your select
  query
* `--insert <table>` creates a simple `INSERT INTO <table>` query with
  the documents on `STDIN`

Additionally, a new flag (`-e` or `--edit`) lets you edit saved SQL
queries in your text editor. This is useful if you've got a long query
with a bunch of joins and don't want to mess about on the command line.

Full changelog below...

---

* [add --order-by helper for ysql](https://github.com/preaction/ETL-Yertl/commit/bdf3fc77b2b254b034ddb648e763ddc40a382cde) ([#136](https://github.com/preaction/ETL-Yertl/issues/136))
* [add sortable field to ysql test](https://github.com/preaction/ETL-Yertl/commit/5cd76f70adfa6d424e0dccc7eee2d2f623c52a94)
* [add --where helper for select queries](https://github.com/preaction/ETL-Yertl/commit/965f4591b7dc615348bfa8429aed5a19679f165f) ([#136](https://github.com/preaction/ETL-Yertl/issues/136))
* [add --select and --insert query helpers to ysql](https://github.com/preaction/ETL-Yertl/commit/41dcbf6f59c298f96577386387522e643a46b8cf) ([#136](https://github.com/preaction/ETL-Yertl/issues/136))
* [add flag to edit SQL query in text editor](https://github.com/preaction/ETL-Yertl/commit/c3d8f1ebc57d2c471f2d0ee907d59cab74fedade) ([#135](https://github.com/preaction/ETL-Yertl/issues/135))
* [update docs to new website at preaction.me](https://github.com/preaction/ETL-Yertl/commit/c367d70fe8fe0d2e69e73c66f9cc31b98b3b145e)
