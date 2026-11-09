#!/usr/bin/env bash
awk -F, 'NR>1 { q[$2]+=$3 } END { for (p in q) if (q[p]>m) { m=q[p]; best=p }; print best, m }' sales.csv > top-product.txt
