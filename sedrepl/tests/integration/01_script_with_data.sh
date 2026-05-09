#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/01_script_with_data.sh - full pipeline: script + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"
source "$SEDREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: substitution ---
cat > "$replfile" <<'EOF'
s/chr/chromosome/

#DATA
chr1
chr8
chr10
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
output=$(sed -f "$src" "$data")
assert_equals "substitution produces correct output" \
    "chromosome1
chromosome8
chromosome10" "$output"

# --- test: delete lines matching pattern ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
/^#/d

#DATA
# comment
data line
# another comment
more data
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
output=$(sed -f "$src" "$data")
assert_equals "delete matching lines" \
    "data line
more data" "$output"

# --- test: field trimming (strip trailing whitespace) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
s/[[:space:]]*$//

#DATA
hello
world
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
output=$(sed -f "$src" "$data")
assert_equals "trailing whitespace stripped" \
    "hello
world" "$output"

summary
