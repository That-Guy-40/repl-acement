#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/04_pretty_print.sh
##
##  _sedrepl_pretty_print syntax-checks and displays the sed script source.
##  A valid script is shown cleanly; an invalid one shows an ERROR header first.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"
source "$SEDREPL"

src=$(mktemp)
trap 'rm -f "$src"' EXIT

# --- test: empty source file → no output, no error ---
: > "$src"
output=$(_sedrepl_pretty_print "$src" 2>&1)
assert_equals "empty source file produces no output" "" "$output"

# --- test: valid script is displayed without ERROR header ---
echo 's/foo/bar/' > "$src"
output=$(_sedrepl_pretty_print "$src" 2>&1)
assert_output_contains "valid script shown in output" \
    's/foo/bar/' _sedrepl_pretty_print "$src"

if echo "$output" | grep -qF "ERROR"; then
    fail "valid script should not trigger ERROR header"
else
    pass "valid script does not trigger ERROR header"
fi

# --- test: invalid script triggers ERROR header ---
printf 's/unclosed' > "$src"
output=$(_sedrepl_pretty_print "$src" 2>&1)
if echo "$output" | grep -qiF "ERROR"; then
    pass "invalid script triggers ERROR header"
else
    fail "invalid script should trigger ERROR header" "got: $output"
fi

# --- test: # comment lines in sed script pass through to display ---
printf '# this is a comment\ns/a/b/\n' > "$src"
assert_output_contains \
    "# comment line shown in pretty-print output" \
    '# this is a comment' \
    _sedrepl_pretty_print "$src"

summary
