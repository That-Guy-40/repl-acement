#!/usr/bin/env bash
grep -rLi timeout logs | LC_ALL=C sort > without-timeout.txt
