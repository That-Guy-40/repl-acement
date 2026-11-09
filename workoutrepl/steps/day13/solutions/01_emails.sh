#!/usr/bin/env bash
grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' input.txt | grep -vE '@@' > emails.txt
