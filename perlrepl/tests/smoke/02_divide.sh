#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/02_divide.sh - unit tests for _perlrepl_divide
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

src=$(mktemp); data=$(mktemp); args=$(mktemp); in=$(mktemp)
trap 'rm -f "$src" "$data" "$args" "$in"' EXIT

# --- test: Perl source + #DATA split ---
cat > "$in" <<'EOF'
print uc($_);

#DATA
hello world
foo bar
EOF

_perlrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "expression ends up in src"       'print uc'    "$src"
assert_file_not_contains "#DATA marker removed from src"   '#DATA'       "$src"
assert_file_contains     "data ends up in data file"       'hello world' "$data"
assert_file_not_contains "#DATA marker removed from data"  '#DATA'       "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
print "hello\n";
EOF

_perlrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains 'expression in src when no #DATA'   'print "hello\n"' "$src"
assert_empty         "data file empty when no #DATA"     "$data"

# --- test: comments are preserved (Perl supports # natively) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
# upcase each line
chomp; print uc($_) . "\n";
EOF

_perlrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "comments preserved in src"       '# upcase each line'       "$src"
assert_file_contains "active expression remains"       'chomp; print uc'          "$src"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS -l
print;

#DATA
hello
EOF

_perlrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '-l'    "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS' "$src"

# --- sourcing the script (as these tests do) must not return failure ---
# (a trailing '[[ … ]] && perlrepl' used to leave status 1, killing set -e callers)
assert_equals "sourcing perlrepl returns 0" "0" \
    "$(bash -c 'source "$1"' _ "$TESTS_DIR/../../perlrepl" >/dev/null 2>&1; echo $?)"

summary
