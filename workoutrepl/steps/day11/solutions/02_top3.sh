#!/usr/bin/env bash
LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 joined.tsv | head -3 | tr '\t' ' ' > top3.txt
