#!/usr/bin/env bash
cut -f2 users.tsv | cut -c1 | tr a-z A-Z | uniq > initials.txt
