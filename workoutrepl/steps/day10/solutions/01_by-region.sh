#!/usr/bin/env bash
awk -F, 'NR>1 { r[$1] += $3*$4 } END { for (k in r) printf "%s\t%.2f\n", k, r[k] }' sales.csv | LC_ALL=C sort > by-region.txt
