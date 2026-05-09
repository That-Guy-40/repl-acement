#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/03_args_section.sh - #ARGS flags are passed through to jq
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$JQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: -r flag produces raw string output ---
cat > "$replfile" <<'EOF'
#ARGS -r
.[] | .name

#DATA
[{"name":"Alice"},{"name":"Bob"}]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS -r written to args file" '-r' "$args"

# shellcheck disable=SC2046
output=$(jq $(cat "$args") -f "$src" "$data")
assert_equals "-r flag strips JSON quotes from strings" \
    "Alice
Bob" "$output"

# --- test: --arg binds a shell variable into jq ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS --arg city Chicago
[.[] | select(.city == $city) | .name]

#DATA
[
  {"name":"Alice","city":"New York"},
  {"name":"Carol","city":"Chicago"}
]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "--arg written to args file" '--arg' "$args"

# shellcheck disable=SC2046
output=$(jq $(cat "$args") -f "$src" "$data")
assert_equals "--arg filter produces correct output" \
    '["Carol"]' "$(echo "$output" | tr -d ' \n')"

# --- test: #ARGS line is stripped from source ---
assert_file_not_contains "#ARGS line not in src" '#ARGS' "$src"

# --- test: #ARGS before filter (order independence) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS -c
.

#DATA
{"x":1}
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
# shellcheck disable=SC2046
output=$(jq $(cat "$args") -f "$src" "$data")
assert_equals "-c flag produces compact output" '{"x":1}' "$output"

summary
