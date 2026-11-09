#!/usr/bin/env bash
find tree -type f -size +100k | LC_ALL=C sort > big.txt
