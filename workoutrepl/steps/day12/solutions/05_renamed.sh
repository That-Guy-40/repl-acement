#!/usr/bin/env bash
mkdir -p renamed
find tree -name '*.txt' -type f -print0 | xargs -0 cp -t renamed
