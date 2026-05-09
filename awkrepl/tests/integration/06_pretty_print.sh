#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/06_pretty_print.sh
##
##  _awkrepl_pretty_print uses 'gawk --pretty-print' to reformat source.
##  Valid AWK is displayed cleanly; invalid AWK triggers an ERROR header.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

src=$(mktemp)
trap 'rm -f "$src"' EXIT

# --- empty source file → no output, no error ---
: > "$src"
output=$(_awkrepl_pretty_print "$src" 2>&1)
assert_equals "empty source file produces no output" "" "$output"

# --- valid AWK is displayed without ERROR header ---
echo '{ print $1 }' > "$src"
output=$(_awkrepl_pretty_print "$src" 2>&1)
assert_output_contains \
    "valid AWK source shown by pretty-printer" \
    'print $1' \
    _awkrepl_pretty_print "$src"

if echo "$output" | grep -qF "ERROR"; then
    fail "valid AWK should not trigger ERROR header"
else
    pass "valid AWK does not trigger ERROR header"
fi

# --- invalid AWK triggers ERROR header ---
printf '{ print $1' > "$src"   # unclosed brace
output=$(_awkrepl_pretty_print "$src" 2>&1)
if echo "$output" | grep -qiF "ERROR"; then
    pass "invalid AWK triggers ERROR header"
else
    fail "invalid AWK should trigger ERROR header" "got: $output"
fi

# --- pretty-printer reformats condensed AWK ---
printf '{print $1}' > "$src"
output=$(_awkrepl_pretty_print "$src" 2>&1)
# gawk --pretty-print adds indentation/spacing; at minimum output is non-empty
if [[ -n "$output" ]]; then
    pass "pretty-printer produces non-empty output for valid source"
else
    fail "pretty-printer produced empty output for valid source"
fi

summary
