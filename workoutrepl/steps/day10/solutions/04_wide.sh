#!/usr/bin/env bash
awk -F, 'NR>1 { printf "%-6s %-8s %4d %8.2f\n", $1, $2, $3, $4 }' sales.csv > wide.txt
