#!/usr/bin/env bash
awk '$(NF-1)==404 { split($4, t, ":"); h[t[2]]++ } END { for (k in h) print k, h[k] }' access.log | LC_ALL=C sort > 404-by-hour.txt
