#!/usr/bin/env bash
awk '{print $1}' access.log | LC_ALL=C sort | uniq -c | LC_ALL=C sort -k1,1nr -k2,2 | head -5 | awk '{print $1, $2}' > top-ips.txt
