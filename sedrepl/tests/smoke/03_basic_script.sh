#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/03_basic_script.sh - verify sed executes a script file correctly
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

script=$(mktemp); data=$(mktemp)
trap 'rm -f "$script" "$data"' EXIT

echo 's/foo/bar/' > "$script"
printf 'foo\nbaz\n' > "$data"

assert_output_equals \
    "sed -f substitution produces correct output" \
    "bar
baz" \
    sed -f "$script" "$data"

echo 's/chr/CHR/' > "$script"
printf 'chr1\nchr8\n' > "$data"

assert_output_equals \
    "sed -f first-occurrence substitution" \
    "CHR1
CHR8" \
    sed -f "$script" "$data"

summary
