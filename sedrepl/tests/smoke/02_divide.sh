#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/02_divide.sh - unit tests for _sedrepl_divide
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"

# source sedrepl to load helper functions without launching the REPL
source "$SEDREPL"

src=$(mktemp); data=$(mktemp); args=$(mktemp); in=$(mktemp)
trap 'rm -f "$src" "$data" "$args" "$in"' EXIT

# --- test: script + #DATA split ---
cat > "$in" <<'EOF'
s/foo/bar/

#DATA
foo
baz
EOF

_sedrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "script ends up in src"          's/foo/bar/' "$src"
assert_file_not_contains "#DATA marker removed from src"  '#DATA'      "$src"
assert_file_contains     "data ends up in data file"      'foo'        "$data"
assert_file_not_contains "#DATA marker removed from data" '#DATA'      "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
s/hello/world/
EOF

_sedrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "script in src when no #DATA"    's/hello/world/' "$src"
assert_empty         "data file empty when no #DATA"  "$data"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS -n
/^chr8/p

#DATA
chr1	100
chr8	200
EOF

_sedrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '-n'          "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS'       "$src"
assert_file_contains     "script still in src"              '/^chr8/p'    "$src"
assert_file_contains     "data has content"                 'chr8'        "$data"

summary
