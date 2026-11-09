#!/usr/bin/env bash
grep -rh -B1 -A1 FATAL logs > context.txt
