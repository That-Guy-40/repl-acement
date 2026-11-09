#!/usr/bin/env bash
comm -23 <(awk '{print $1}' access.log | LC_ALL=C sort -u) <(cut -f1 geo.tsv | LC_ALL=C sort) > unknown-ips.txt
