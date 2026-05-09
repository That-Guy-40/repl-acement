#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/04_comment_preservation.sh
##
##  perlrepl preserves # comments — unlike awkrepl which strips them.
##  Perl supports # comments natively; they act as documentation without
##  interfering with execution.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- inline comment lines are preserved ---
cat > "$replfile" <<'EOF'
# upcase each input line
chomp; print uc($_) . "\n";

#DATA
hello
world
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "inline comment preserved in src"  '# upcase each input line'  "$src"
assert_file_contains "active expression also present"   'print uc'                  "$src"

# Perl ignores # comments; the expression runs correctly with them present
output=$(perl -n "$src" "$data")
assert_equals "commented source still executes correctly" \
    "HELLO
WORLD" "$output"

# --- commented-out code is preserved (not stripped) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
# chomp; print lc($_) . "\n";
chomp; print uc($_) . "\n";

#DATA
Hello
EOF

_perlrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains     "commented-out code preserved"     '# chomp; print lc'  "$src"
assert_file_contains     "active code present"               'print uc'           "$src"

output=$(perl -n "$src" "$data")
assert_equals "only active (non-commented) code runs" "HELLO" "$output"

summary
