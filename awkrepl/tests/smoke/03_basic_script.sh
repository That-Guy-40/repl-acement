#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/03_basic_script.sh - verify gawk executes a script file correctly
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

script=$(mktemp); data=$(mktemp)
trap 'rm -f "$script" "$data"' EXIT

echo '{ print $1 }' > "$script"
printf 'hello world\nfoo bar\n' > "$data"

assert_output_equals \
    "gawk -f field extraction" \
    "hello
foo" \
    gawk -f "$script" "$data"

echo 'END { print NR }' > "$script"
printf 'a\nb\nc\n' > "$data"

assert_output_equals \
    "gawk -f END block counts lines" \
    "3" \
    gawk -f "$script" "$data"

summary
