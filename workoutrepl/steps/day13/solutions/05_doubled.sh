#!/usr/bin/env bash
grep -E '\b([a-z]+) \1\b' input.txt > doubled.txt
