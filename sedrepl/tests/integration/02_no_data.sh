#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/02_no_data.sh - no #DATA section → sed processes empty input
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"
source "$SEDREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: data file is empty when there is no #DATA ---
cat > "$replfile" <<'EOF'
s/foo/bar/
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "no #DATA → data file is empty" "$data"

# --- test: sed on empty data file produces no output and exits 0 ---
output=$(sed -f "$src" "$data")
assert_equals "sed on empty data produces empty output" "" "$output"

# --- test: script is still captured correctly ---
assert_file_contains "script present in src" 's/foo/bar/' "$src"

summary
