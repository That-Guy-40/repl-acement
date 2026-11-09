#!/usr/bin/env bash
grep -oE '\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b' input.txt > iso-dates.txt
