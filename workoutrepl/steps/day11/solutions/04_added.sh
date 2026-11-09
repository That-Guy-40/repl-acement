#!/usr/bin/env bash
comm -13 <(LC_ALL=C sort old-users.txt) <(LC_ALL=C sort new-users.txt) > added.txt
