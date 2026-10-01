#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/02_divide.sh - unit tests for _yqrepl_divide
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

src=$(mktemp); data=$(mktemp); args=$(mktemp); in=$(mktemp)
trap 'rm -f "$src" "$data" "$args" "$in"' EXIT

# --- test: yq expression + #DATA split ---
cat > "$in" <<'EOF'
.[] | .name

#DATA
- name: Alice
- name: Bob
EOF

_yqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "expression ends up in src"        '.[] | .name'  "$src"
assert_file_not_contains "#DATA marker removed from src"    '#DATA'        "$src"
assert_file_contains     "data ends up in data file"        'name: Alice'  "$data"
assert_file_not_contains "#DATA marker removed from data"   '#DATA'        "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
{"greeting": "hello"}
EOF

_yqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "expression in src when no #DATA"  '{"greeting": "hello"}' "$src"
assert_empty         "data file empty when no #DATA"    "$data"

# --- test: comments are preserved (yq supports # natively) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
# select adults
.[] | select(.age >= 18) | .name
EOF

_yqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "comments preserved in src"            '# select adults'              "$src"
assert_file_contains "active expression remains after comment" '.[] | select(.age >= 18)'  "$src"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS -o json
.[] | .name

#DATA
- name: Alice
EOF

_yqrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '-o'     "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS'  "$src"

# --- sourcing the script (as these tests do) must not return failure ---
# (a trailing '[[ … ]] && yqrepl' used to leave status 1, killing set -e callers)
assert_equals "sourcing yqrepl returns 0" "0" \
    "$(bash -c 'source "$1"' _ "$TESTS_DIR/../../yqrepl" >/dev/null 2>&1; echo $?)"

summary
