#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016,SC2046
##  integration/03_args_section.sh - #ARGS flags are forwarded to perl
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: -l flag (auto-chomp + newline on print) ---
cat > "$replfile" <<'EOF'
#ARGS -l
print uc;

#DATA
hello
world
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS -l written to args file" '-l' "$args"

output=$(perl -n $(cat "$args") "$src" "$data")
assert_equals "-l flag chomps and re-adds newlines on print" \
    "HELLO
WORLD" "$output"

# --- test: -a flag (auto-split into @F) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS -a
print "$F[1]\n";

#DATA
hello world
foo bar
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS -a written to args file" '-a' "$args"

output=$(perl -n $(cat "$args") "$src" "$data")
assert_equals "-a flag auto-splits into @F for second field" \
    "world
bar" "$output"

summary
