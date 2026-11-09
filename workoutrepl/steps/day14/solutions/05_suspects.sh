#!/usr/bin/env bash
awk '$(NF-1)==401 { c[$1]++ } END { for (ip in c) if (c[ip] >= 5) print ip, c[ip] }' access.log | LC_ALL=C sort > suspects.txt
