#!/usr/bin/env bash
grep -rli timeout logs | LC_ALL=C sort > with-timeout.txt
