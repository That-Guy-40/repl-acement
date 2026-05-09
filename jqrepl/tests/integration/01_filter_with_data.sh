#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/01_filter_with_data.sh - full pipeline: filter + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$JQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: field extraction ---
cat > "$replfile" <<'EOF'
.[] | .name

#DATA
[
  {"name": "Alice", "age": 30},
  {"name": "Bob",   "age": 17}
]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
output=$(jq -f "$src" "$data")
assert_equals "field extraction produces correct output" \
    '"Alice"
"Bob"' "$output"

# --- test: select filter ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
[.[] | select(.age >= 18) | .name]

#DATA
[
  {"name": "Alice", "age": 30},
  {"name": "Bob",   "age": 17},
  {"name": "Carol", "age": 25}
]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
output=$(jq -f "$src" "$data")
assert_equals "select filter produces correct output" \
    '["Alice","Carol"]' "$(echo "$output" | tr -d ' \n')"

# --- test: object construction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
.[] | {n: .name, a: .age}

#DATA
[{"name":"X","age":1}]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
output=$(jq -c -f "$src" "$data")
assert_equals "object construction produces correct output" \
    '{"n":"X","a":1}' "$output"

summary
