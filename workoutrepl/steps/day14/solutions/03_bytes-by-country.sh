#!/usr/bin/env bash
join -t $'\t' <(awk '{print $1"\t"$NF}' access.log | LC_ALL=C sort -k1,1) <(LC_ALL=C sort -k1,1 geo.tsv) \
    | awk -F'\t' '{ b[$3] += $2 } END { for (c in b) printf "%s\t%d\n", c, b[c] }' | LC_ALL=C sort > bytes-by-country.tsv
