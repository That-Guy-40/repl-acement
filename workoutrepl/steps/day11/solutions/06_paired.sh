#!/usr/bin/env bash
paste -d, <(cut -f2 users.tsv) <(cut -f1 users.tsv) > paired.txt
