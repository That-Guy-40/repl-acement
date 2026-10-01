#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  integration/08_header_matching.sh - only real #DATA / #ARGS lines are
##  headers; comments that merely start with "data" or "arg" stay comments.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$(cd "$TESTS_DIR/../.." && pwd)/jqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$TOOL"

in=$(mktemp); src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$in" "$src" "$data" "$args"' EXIT

# divide_lines LINE... — write the lines as the edited file and divide it
divide_lines() {
    printf '%s\n' "$@" > "$in"
    : > "$src"; : > "$data"; : > "$args"
    _jqrepl_divide "$in" "$src" "$data" "$args"
}

# --- comments that start with "data" / "arg" are not headers ---
divide_lines \
    '# Database notes: the input is CSV' \
    '# data comes from the nightly export' \
    '# Args are cool' \
    '# arguably the best part' \
    '# Arguments: none needed' \
    'PROGRAM_LINE' \
    '#ARGS -n' \
    '#DATA' \
    'first data line'
assert_equals "only the real #ARGS options are extracted" "-n" "$(cat "$args")"
assert_equals "data is only what follows the real #DATA line" "first data line" "$(cat "$data")"
assert_file_contains     "the program line stays in the source" "PROGRAM_LINE" "$src"
assert_file_not_contains "the #ARGS header is removed from the source" "#ARGS" "$src"
assert_file_not_contains "the #DATA header is removed from the source" "#DATA" "$src"
assert_file_contains     "'# Database…' stays in the source as a comment" "# Database notes" "$src"
assert_file_contains     "'# Args are cool' stays in the source as a comment" "# Args are cool" "$src"
# --- every documented header spelling still works ---
for hdr in '#DATA' '# DATA' '#data' '#Data:'; do
    divide_lines 'PROGRAM_LINE' "$hdr" 'row'
    assert_equals "'$hdr' is a #DATA header" "row" "$(cat "$data")"
done
for hdr in '#ARGS -n' '# args: -n' '#ARGUMENTS -n' '#ARGS:-n' '#arg -n'; do
    divide_lines 'PROGRAM_LINE' "$hdr"
    assert_equals "'$hdr' is an #ARGS header" "-n" "$(cat "$args")"
done

# --- '#ARGS' with nothing after it is a header with no options ---
divide_lines 'PROGRAM_LINE' '#ARGS'
assert_equals            "bare #ARGS gives no options" "" "$(tr -d "[:space:]" < "$args")"
assert_file_not_contains "bare #ARGS is removed from the source" "#ARGS" "$src"

# --- '#DATA' followed by more words is a comment, not a header ---
divide_lines 'PROGRAM_LINE' '# data is below' 'not data'
assert_empty "'# data is below' does not start the data section" "$data"

# --- '#DATA' may be the very first line (a file that is only data) ---
# (a '1,/re/' sed range used to miss a header on line 1 and send every data
#  row into the program as well)
divide_lines '#DATA' 'row1' 'row2'
assert_equals "#DATA on line 1: the program is empty" "" "$(tr -d '[:space:]' < "$src")"
assert_equals "#DATA on line 1: every row is data" "row1
row2" "$(cat "$data")"

divide_lines '#data:' 'row1'
assert_equals "'#data:' on line 1: the program is empty" "" "$(tr -d '[:space:]' < "$src")"
assert_equals "'#data:' on line 1: the row is data" "row1" "$(cat "$data")"

divide_lines '#DATA' 'row1' '#DATA' 'row2'
assert_equals "#DATA on line 1 and again later: the program is empty" "" "$(tr -d '[:space:]' < "$src")"
assert_equals "#DATA on line 1 and again later: the rows are data once each" "row1
row2" "$(cat "$data")"

divide_lines '' '#DATA' 'row1'
assert_equals "#DATA after a blank first line: the row is data" "row1" "$(cat "$data")"

summary
