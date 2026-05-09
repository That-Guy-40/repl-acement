#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/02_null_input.sh - filters without #DATA run in null-input mode
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$JQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: data file is empty when no #DATA ---
cat > "$replfile" <<'EOF'
{greeting: "hello", nums: [range(3)]}
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "no #DATA → data file is empty" "$data"

# --- test: filter runs correctly with -n when data is empty ---
output=$(jq -n -f "$src")
assert_equals "null-input filter produces correct output" \
    '{"greeting":"hello","nums":[0,1,2]}' \
    "$(echo "$output" | tr -d ' \n')"

# --- test: built-in function without data ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
[range(5)] | add
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "no #DATA → data file is empty" "$data"
assert_output_equals "range + add without data" "10" jq -n -f "$src"

summary
