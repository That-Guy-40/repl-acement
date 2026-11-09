#!/usr/bin/env bash
join -t $'\t' <(LC_ALL=C sort -k1,1 users.tsv) <(LC_ALL=C sort -k1,1 logins.tsv) | cut -f2,3 | LC_ALL=C sort > joined.tsv
