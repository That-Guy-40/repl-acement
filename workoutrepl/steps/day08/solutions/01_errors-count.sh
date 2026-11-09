#!/usr/bin/env bash
grep -rcw --include='*.log' ERROR logs | LC_ALL=C sort > errors-count.txt
