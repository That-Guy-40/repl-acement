#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/03_basic_filter.sh - verify jq executes a filter correctly
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

filter=$(mktemp)
trap 'rm -f "$filter"' EXIT

echo '.[] | .name' > "$filter"

assert_output_equals \
    "jq -f filter produces correct output" \
    '"Alice"
"Bob"' \
    jq -f "$filter" <<< '[{"name":"Alice"},{"name":"Bob"}]'

echo '[range(5)] | add' > "$filter"
assert_output_equals \
    "jq -n evaluates expression against null input" \
    "10" \
    jq -n -f "$filter"

summary
