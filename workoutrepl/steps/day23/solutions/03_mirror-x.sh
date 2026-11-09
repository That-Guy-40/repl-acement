#!/usr/bin/env bash
rsync -a --exclude='*.tmp' --exclude='cache/' src/ mirror-x/
