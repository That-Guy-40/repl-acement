#!/usr/bin/env bash
grep -rniw disk logs | LC_ALL=C sort > disk.txt
