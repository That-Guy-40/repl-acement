#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/03_needs_n.sh - unit tests for _perlrepl_needs_n heuristic
##
##  _perlrepl_needs_n returns 0 (true) for bare per-line expressions that
##  need the -n loop; returns 1 (false) for full scripts with control flow
##  or block keywords.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

src=$(mktemp)
trap 'rm -f "$src"' EXIT

# --- bare expression → needs -n ---
echo 'print uc($_);' > "$src"
if _perlrepl_needs_n "$src"; then
    pass "bare print expression → needs -n"
else
    fail "bare print expression → needs -n"
fi

# --- chomp + print → needs -n ---
echo 'chomp; print uc($_) . "\n";' > "$src"
if _perlrepl_needs_n "$src"; then
    pass "chomp; print expression → needs -n"
else
    fail "chomp; print expression → needs -n"
fi

# --- BEGIN block → does NOT need -n ---
printf 'BEGIN { print "header\n" }\n{ print $_ }\n' > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "BEGIN block → does not need -n"
else
    fail "BEGIN block → does not need -n"
fi

# --- while loop → does NOT need -n ---
printf 'while (<>) { print uc($_) }\n' > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "while loop → does not need -n"
else
    fail "while loop → does not need -n"
fi

# --- foreach → does NOT need -n ---
printf 'foreach my $line (@lines) { print $line }\n' > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "foreach loop → does not need -n"
else
    fail "foreach loop → does not need -n"
fi

# --- use statement → does NOT need -n ---
printf 'use strict;\nuse warnings;\nprint "ok\n";\n' > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "use statement → does not need -n"
else
    fail "use statement → does not need -n"
fi

# --- sub definition → does NOT need -n ---
printf 'sub greet { print "hello $_[0]\n" }\ngreet("world");\n' > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "sub definition → does not need -n"
else
    fail "sub definition → does not need -n"
fi

# --- comment-only first line, bare expr after → needs -n ---
printf '# upcase\nprint uc($_);\n' > "$src"
if _perlrepl_needs_n "$src"; then
    pass "comment then bare expr → needs -n"
else
    fail "comment then bare expr → needs -n"
fi

# --- empty file → does NOT need -n ---
: > "$src"
if ! _perlrepl_needs_n "$src"; then
    pass "empty file → does not need -n"
else
    fail "empty file → does not need -n"
fi

summary
