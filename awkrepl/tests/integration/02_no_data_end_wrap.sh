#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/02_no_data_end_wrap.sh
##
##  Without #DATA, a bare expression is wrapped in END{} so it runs exactly
##  once against empty input — analogous to a one-shot calculation.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: bare expression wrapped in END{} when there is no #DATA ---
cat > "$replfile" <<'EOF'
print "hello"
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty         "no #DATA → data file is empty"      "$data"
assert_file_contains "bare expression wrapped in END{}"   'END {' "$src"

output=$(gawk -f "$src" "$data")
assert_equals "END-wrapped expression executes correctly" "hello" "$output"

# --- test: already-wrapped source is NOT double-wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
END { print "already wrapped" }
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
# should still contain exactly one 'END' (not two)
count=$(grep -c 'END' "$src")
assert_equals "source with END{} is not double-wrapped" "1" "$count"

output=$(gawk -f "$src" "$data")
assert_equals "pre-wrapped END{} executes correctly" "already wrapped" "$output"

# --- test: BEGIN{} is not wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
BEGIN { print "begin" }
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "BEGIN{} source not wrapped in END{}" 'END {' "$src"

output=$(gawk -f "$src" "$data")
assert_equals "BEGIN{} executes correctly without wrapping" "begin" "$output"

summary
