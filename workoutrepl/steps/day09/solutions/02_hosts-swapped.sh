#!/usr/bin/env bash
sed -E 's/^([^\t#]+)\t(.+)$/\2\t\1/' hosts.txt > hosts-swapped.txt
