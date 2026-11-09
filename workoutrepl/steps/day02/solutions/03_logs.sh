#!/usr/bin/env bash
shopt -s globstar dotglob
printf '%s\n' incoming/**/*.log | LC_ALL=C sort > logs.txt
