#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/01_script_with_data.sh - full pipeline: source + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: bare expression auto-wrapped with -n ---
cat > "$replfile" <<'EOF'
chomp; print uc($_) . "\n";

#DATA
hello world
foo bar
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
output=$(perl -n "$src" "$data")
assert_equals "bare expression + -n upcases lines" \
    "HELLO WORLD
FOO BAR" "$output"

# --- test: grep-like filter ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
print if /^chr8/;

#DATA
chr1	100
chr8	50
chr10	300
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
output=$(perl -n "$src" "$data")
assert_equals "grep-like filter selects matching lines" "chr8	50" "$output"

# --- test: full script (no -n) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
my @lines;
while (<>) { chomp; push @lines, $_ }
print scalar(@lines) . "\n";

#DATA
a
b
c
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
output=$(perl "$src" "$data")
assert_equals "full while-loop script counts lines" "3" "$output"

# --- test: auto-wrap heuristic dispatches correctly ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
chomp; print "$.: $_\n";

#DATA
alpha
beta
gamma
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
auto_n=''
if _perlrepl_needs_n "$src"; then auto_n='-n'; fi
output=$(perl $auto_n "$src" "$data")
assert_equals "auto-n heuristic adds line numbers" \
    "1: alpha
2: beta
3: gamma" "$output"

summary
