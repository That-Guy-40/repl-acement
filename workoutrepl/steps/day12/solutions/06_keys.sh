#!/usr/bin/env bash
find tree -name '*.key' -exec chmod 600 {} +
find tree -name '*.key' -exec ls -l {} +
