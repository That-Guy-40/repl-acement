#!/usr/bin/env bash
find tree -type f -print0 | tr -cd '\0' | wc -c > count.txt
