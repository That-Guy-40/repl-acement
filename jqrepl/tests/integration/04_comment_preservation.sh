#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/04_comment_preservation.sh
##
##  jq supports # comments in filter files natively; unlike awkrepl, jqrepl
##  does not strip them — verify they survive _jqrepl_divide unchanged.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$JQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: inline comments survive the divide step ---
cat > "$replfile" <<'EOF'
# select adults only
[.[] | select(.age >= 18) | .name]

#DATA
[
  {"name":"Alice","age":30},
  {"name":"Bob","age":17}
]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains     "inline comment preserved in src" '# select adults' "$src"
assert_file_not_contains "#DATA not confused with comment" '#DATA'            "$src"

# --- test: commented-out filter lines survive ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
# .[] | .name
.[] | .age

#DATA
[{"name":"Alice","age":30}]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "commented-out filter line preserved" '# .[] | .name' "$src"
assert_file_contains "active filter line preserved"        '.[] | .age'    "$src"

# --- test: jq can actually execute a filter with a comment in it ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
# returns names
.[] | .name

#DATA
[{"name":"Alice"}]
EOF

_jqrepl_divide "$replfile" "$src" "$data" "$args"
output=$(jq -f "$src" "$data" 2>&1)
assert_equals "jq executes filter containing comments" '"Alice"' "$output"

summary
