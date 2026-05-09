#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/03_args_section.sh - #ARGS flags are passed through to gawk
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: -v sets a variable ---
cat > "$replfile" <<'EOF'
#ARGS -v sep=:
{ print $1 sep $2 }

#DATA
hello world
foo bar
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS value in args file" '-v' "$args"
assert_file_not_contains "#ARGS stripped from src" '#ARGS' "$src"

# shellcheck disable=SC2046
output=$(gawk $(cat "$args") -f "$src" "$data")
assert_equals "-v sep=: joins fields with colon" \
    "hello:world
foo:bar" "$output"

# --- test: -v OFS changes output field separator ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS -v OFS=,
{ print $1, $2, $3 }

#DATA
a b c
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
# shellcheck disable=SC2046
output=$(gawk $(cat "$args") -f "$src" "$data")
assert_equals "-v OFS=, produces CSV-style output" "a,b,c" "$output"

summary
