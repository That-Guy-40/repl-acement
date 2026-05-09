#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/02_divide.sh - unit tests for _jqrepl_divide
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"

# source jqrepl to load helper functions without launching the REPL
source "$JQREPL"

# temp files, cleaned up on exit
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$src" "$data" "$args"' EXIT

# --- test: filter + #DATA split ---
in=$(mktemp)
trap 'rm -f "$in"' EXIT
cat > "$in" <<'EOF'
.[] | .name

#DATA
["Alice","Bob"]
EOF

_jqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "filter ends up in src"      '.[] | .name' "$src"
assert_file_not_contains "#DATA marker removed from src" '#DATA'     "$src"
assert_file_contains     "data ends up in data file"  '"Alice"'     "$data"
assert_file_not_contains "#DATA marker removed from data" '#DATA'    "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
{a: 1}
EOF

_jqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "{a: 1} in src"        '{a: 1}' "$src"
assert_empty         "data file is empty when no #DATA" "$data"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS -r
.[] | .name

#DATA
["Alice"]
EOF

_jqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '-r'       "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS'    "$src"
assert_file_contains     "filter still in src"              '.[] | .name' "$src"

summary
