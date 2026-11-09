#!/usr/bin/env bash
printf '%s\n' incoming/*.[jJ][pP][gG] | LC_ALL=C sort > images.txt
