#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/04_auto_wrap.sh
##
##  awkrepl's Perl heuristic inspects the first non-blank, non-comment line
##  of the source. If it starts with a plain statement (no leading '{',
##  'BEGIN'/'END', pattern reference, or regex) the source is wrapped:
##    - in '{ }' when #DATA is present (runs per-line)
##    - in 'END { }' when #DATA is absent (runs once, on empty input)
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- bare statement + data → wrapped in { } ---
cat > "$replfile" <<'EOF'
print $1

#DATA
hello world
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains     "bare statement+data wrapped in { }" '{'     "$src"
assert_file_not_contains "bare statement+data NOT wrapped in END{}" 'END' "$src"
output=$(gawk -f "$src" "$data")
assert_equals "wrapped { } executes per-line" "hello" "$output"

# --- bare statement, no data → wrapped in END { } ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
print "standalone"
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "bare statement without data wrapped in END{}" 'END {' "$src"
output=$(gawk -f "$src" "$data")
assert_equals "END{}-wrapped statement executes once" "standalone" "$output"

# --- source starting with { } → NOT wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
{ print toupper($0) }

#DATA
hello
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
count=$(grep -c '{' "$src")
assert_equals "source with { } has exactly one opening brace" "1" "$count"
output=$(gawk -f "$src" "$data")
assert_equals "explicit { } executes correctly" "HELLO" "$output"

# --- NR pattern → NOT wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
NR == 1 { print "first:", $0 }

#DATA
alpha
beta
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "NR pattern not double-wrapped" 'END {' "$src"
output=$(gawk -f "$src" "$data")
assert_equals "NR pattern executes correctly" "first: alpha" "$output"

# --- field-reference pattern ($1 ~ /…/) → NOT wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
$1 ~ /^chr/ { print $1 }

#DATA
chr8	100
notchr	200
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "field-ref pattern not wrapped" 'END {' "$src"
output=$(gawk -f "$src" "$data")
assert_equals "field-ref pattern executes correctly" "chr8" "$output"

# --- regex pattern (/…/) → NOT wrapped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
/^foo/

#DATA
foo bar
baz
foo qux
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "regex pattern not wrapped" 'END {' "$src"
output=$(gawk -f "$src" "$data")
assert_equals "regex pattern (implicit print) executes correctly" \
    "foo bar
foo qux" "$output"

summary
