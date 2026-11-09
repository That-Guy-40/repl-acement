#!/usr/bin/env bash
find tree -type f ! -newer tree/REF ! -path tree/REF | LC_ALL=C sort > old.txt
