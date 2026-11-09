#!/usr/bin/env bash
set -euo pipefail
rm -rf links; mkdir -p links
printf 'original\n' > links/data.txt
ln links/data.txt links/data.hard
ln -s data.txt links/data.sym
printf 'appended\n' >> links/data.hard
