---
author: preaction
title: Yertl -- ETL with a Shell
---

# Yertl - ETL with a Shell

Yertl is an ETL (Extract, Transform, Load) system for working with structured data
with a command-line.

## Getting Started

Install the latest version of Yertl from CPAN.

    cpan ETL::Yertl

Check out the documentation for the Yertl commands:

### Input/Output

* [yfrom - Convert formatted data (JSON, CSV) to a Yertl feed (YAML)](/pod/yfrom.html)
* [yto - Convert Yertl feed (YAML) to an output format (JSON, CSV)](/pod/yto.html)
* [ygrok - Parse lines of plain text into documents](/pod/ygrok.html)
* [ysql - Read/write to/from a SQL database](/pod/ysql.html)

### Filter/Transform

* [ymask - Filter by properties using a simple mask](/pod/ymask.html)
* [yq - A transform mini-language](/pod/yq.html)

## Other Resources

### Filter/Transform

* [jq - A transform mini-language for JSON](http://stedolan.github.io/jq/)
