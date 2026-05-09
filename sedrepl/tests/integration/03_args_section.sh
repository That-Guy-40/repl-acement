#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/03_args_section.sh - #ARGS flags are passed through to sed
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"
source "$SEDREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: -n suppresses auto-print; p flag selects matching lines ---
cat > "$replfile" <<'EOF'
#ARGS -n
/^chr8/p

#DATA
chr1	100	200
chr8	50	75
chr10	300	400
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS -n written to args file" '-n' "$args"
assert_file_not_contains "#ARGS line stripped from src" '#ARGS' "$src"

# shellcheck disable=SC2046
output=$(sed $(cat "$args") -f "$src" "$data")
assert_equals "-n + /p flag selects matching lines only" \
    "chr8	50	75" "$output"

# --- test: multiple flags in #ARGS ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS -n -e
/chr8/p

#DATA
chr1
chr8
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "multiple args written" '-n' "$args"

# --- test: #ARGS and #DATA can appear in any order (ARGS first) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS -n
s/chr/CHR/
p

#DATA
chr1
chr8
EOF

_sedrepl_divide "$replfile" "$src" "$data" "$args"
# shellcheck disable=SC2046
output=$(sed $(cat "$args") -f "$src" "$data")
assert_equals "substitution with -n and p prints only matching lines" \
    "CHR1
CHR8" "$output"

summary
