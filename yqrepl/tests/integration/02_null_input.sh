#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/02_null_input.sh - yq --null-input when no #DATA present
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: null-input generates output without data file ---
cat > "$replfile" <<'EOF'
{"greeting": "hello", "target": "world"}
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "no data file when no #DATA section" "$data"

_expr=$(cat "$src")
output=$(yq eval --null-input "$_expr")
assert_equals "null-input produces greeting field" "hello" \
    "$(echo "$output" | yq eval '.greeting' -)"

# --- test: null-input for list generation ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
[{"name": "x"}, {"name": "y"}, {"name": "z"}]
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
_expr=$(cat "$src")
output=$(yq eval --null-input "$_expr | length")
assert_equals "null-input list has correct length" "3" "$output"

summary
