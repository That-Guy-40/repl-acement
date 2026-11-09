#!/usr/bin/env bash
awk '{ s[$(NF-1)]++ } END { for (c in s) print c, s[c] }' access.log | LC_ALL=C sort > status-hist.txt
