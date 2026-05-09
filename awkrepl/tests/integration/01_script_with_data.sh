#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/01_script_with_data.sh - full pipeline: script + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: field extraction ---
cat > "$replfile" <<'EOF'
{ print $2 }

#DATA
hello world
foo bar
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
output=$(gawk -f "$src" "$data")
assert_equals "field extraction (second field)" \
    "world
bar" "$output"

# --- test: pattern + action ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
/^chr8/ { print $1, $3 }

#DATA
chr1	100	200
chr8	50	75
chr10	300	400
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
output=$(gawk -f "$src" "$data")
assert_equals "pattern/action on matching lines" "chr8 75" "$output"

# --- test: aggregation in END block ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
{ sum += $1 }
END { print sum }

#DATA
10
20
30
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
output=$(gawk -f "$src" "$data")
assert_equals "accumulation in END block" "60" "$output"

summary
