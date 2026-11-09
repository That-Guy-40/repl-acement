#!/usr/bin/env bash
rsync -a src/ synced/
rsync -an --delete -i src-v2/ synced/
rsync -a --delete src-v2/ synced/
