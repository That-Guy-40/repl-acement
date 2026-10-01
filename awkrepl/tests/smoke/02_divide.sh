#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/02_divide.sh - unit tests for _awkrepl_divide
##
##  Note: _awkrepl_divide strips comments and blank lines from the source
##  and applies auto-wrapping heuristics — behaviour that distinguishes
##  awkrepl from the simpler sedrepl / jqrepl adaptations.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"

# source awkrepl to load helper functions without launching the REPL
# (_trim_blanks uses a mktemp file under ${TMPDIR:-/tmp}, not CWD; we cd to
# the awkrepl dir only for consistency with the other tests)
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

src=$(mktemp); data=$(mktemp); args=$(mktemp); in=$(mktemp)
trap 'rm -f "$src" "$data" "$args" "$in"' EXIT

# --- test: AWK source + #DATA split ---
cat > "$in" <<'EOF'
{ print $1 }

#DATA
hello world
foo bar
EOF

_awkrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "script ends up in src"          '{ print $1 }' "$src"
assert_file_not_contains "#DATA marker removed from src"  '#DATA'        "$src"
assert_file_contains     "data ends up in data file"      'hello world'  "$data"
assert_file_not_contains "#DATA marker removed from data" '#DATA'        "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
END { print NR }
EOF

_awkrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "script in src when no #DATA"   'END { print NR }' "$src"
assert_empty         "data file empty when no #DATA" "$data"

# --- test: comments stripped from source (awkrepl-specific behaviour) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
# this comment should be removed
{ print $2 }
EOF

_awkrepl_divide "$in" "$src" "$data" "$args"

assert_file_not_contains "comments stripped from src" '# this comment' "$src"
assert_file_contains     "AWK code remains after comment strip" '{ print $2 }' "$src"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS -v OFS=,
{ print $1, $2 }

#DATA
hello world
EOF

_awkrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '-v'    "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS' "$src"

summary
