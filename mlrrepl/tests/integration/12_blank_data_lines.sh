#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  integration/12_blank_data_lines.sh
##
##  Blank lines at the start or end of the #DATA section must not reach
##  Miller: its CSV reader takes an empty line as a one-field row and fails
##  with 'CSV header/data length mismatch'. A blank line after '#DATA' is
##  common, and most editors leave one at the end of the file. Blank lines
##  in the middle are the user's business (with --csvlite they separate
##  schema blocks) and are kept.
##
##  Regression test: the data used to be passed to mlr unchanged, so a
##  trailing blank line printed the results and then an mlr error.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

replfile=$(mktemp); src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- trailing blank lines (what an editor leaves) are dropped ---
printf '$c = $a + $b;\n#DATA\na,b\n1,2\n3,4\n\n   \n\n' > "$replfile"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_equals "trailing blank lines are removed from the data" $'a,b\n1,2\n3,4' "$(cat "$data")"
output=$(mlr --csv put -f "$src" "$data" 2>&1); rc=$?
assert_equals "mlr exits 0 on data that had trailing blank lines" 0 "$rc"
assert_equals "no mismatch error after the results" $'a,b,c\n1,2,3\n3,4,7' "$output"

# --- a blank line right after #DATA is dropped ---
printf '$c = $a + $b;\n\n#DATA\n\na,b\n1,2\n' > "$replfile"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_equals "leading blank line is removed from the data" $'a,b\n1,2' "$(cat "$data")"
output=$(mlr --csv put -f "$src" "$data" 2>&1); rc=$?
assert_equals "mlr exits 0 on data that had a leading blank line" 0 "$rc"

# --- blank lines in the middle are kept ---
printf '$c = 1;\n#DATA\na,b\n1,2\n\nc,d\n3,4\n' > "$replfile"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_equals "a blank line in the middle of the data is kept" $'a,b\n1,2\n\nc,d\n3,4' "$(cat "$data")"

# --- data that is only blank lines ends up empty (the runner prints its hint) ---
printf '$c = 1;\n#DATA\n\n\n' > "$replfile"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "data of only blank lines is emptied" "$(cat "$data")"

# --- no data at all still works (nothing to strip) ---
printf '$c = 1;\n' > "$replfile"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_empty "no #DATA: data file stays empty" "$(cat "$data")"

# --- negative control: Miller really does reject a blank line (so the strip matters) ---
printf 'a,b\n1,2\n\n' > "$data"
if mlr --csv cat "$data" >/dev/null 2>&1; then
    fail "negative control: this mlr accepts a trailing blank line, so this suite proves nothing"
else
    pass "negative control: mlr rejects a trailing blank line"
fi

summary
