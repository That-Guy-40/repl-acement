#!/usr/bin/env bash
grep -owE '#[0-9a-fA-F]{6}' input.txt > hex.txt
