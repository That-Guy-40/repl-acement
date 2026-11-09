#!/usr/bin/env bash
grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' logs | LC_ALL=C sort -u > ips.txt
