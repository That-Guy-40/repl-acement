#!/usr/bin/env bash
comm -23 <(LC_ALL=C sort old-users.txt) <(LC_ALL=C sort new-users.txt) > removed.txt
