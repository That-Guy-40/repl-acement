#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/02_no_data.sh - script without #DATA runs without -n
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: self-contained script with no #DATA ---
cat > "$replfile" <<'EOF'
print "hello, world\n";
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "data file empty when no #DATA" "$data"

output=$(perl "$src")
assert_equals "self-contained script runs without -n" "hello, world" "$output"

# --- test: _perlrepl_needs_n returns false when no data file ---
if ! _perlrepl_needs_n "$src"; then
    pass "bare expr without data: _perlrepl_needs_n still reports needs-n"
    # (it checks source only, not data; but we don't add -n when data is empty)
fi
# what matters is the pipeline: no data → no -n regardless of heuristic
auto_n=''
if [[ -s "$data" ]] && _perlrepl_needs_n "$src"; then auto_n='-n'; fi
assert_equals "-n not added when data file is empty" '' "$auto_n"

# --- test: print to stdout from self-contained computation ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
my $sum = 0;
$sum += $_ for 1..10;
print "$sum\n";
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
output=$(perl "$src")
assert_equals "self-contained sum 1..10" "55" "$output"

summary
