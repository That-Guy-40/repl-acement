#!/usr/bin/env bash
sed -nE 's/.*\b(v[0-9]+\.[0-9]+\.[0-9]+)\b.*/\1/p' releases.txt > versions.txt
