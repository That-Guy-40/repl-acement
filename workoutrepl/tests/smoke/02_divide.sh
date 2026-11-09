#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/02_divide.sh - unit tests for _wr_divide / _wr_header: the REPL's own
##  headers (#DAY #FILE #RUN #MODE #TIMEOUT #FRESH), the body after the LAST
##  header, narration dropped, and the family's #DATA split.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKOUTREPL="$TESTS_DIR/../../workoutrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$WORKOUTREPL"

body=$(mktemp); data=$(mktemp); hdrs=$(mktemp); in=$(mktemp)
trap 'rm -f "$body" "$data" "$hdrs" "$in"' EXIT

# --- test: narration, headers, body, #DATA ---
cat > "$in" <<'EOF'
# day 7 · tidy.sh — narration above the first header is never written
# Run it twice: this line is a comment, not a #RUN header (space after the #)
#DAY 7
#FILE tidy.sh
#RUN ./tidy.sh downloads
#!/usr/bin/env bash
echo "the body starts after the last header"

#DATA
line one
line two
EOF

_wr_divide "$in" "$body" "$data" "$hdrs"

assert_equals "DAY header parsed"  "7"                  "$(_wr_header "$hdrs" DAY)"
assert_equals "FILE header parsed" "tidy.sh"            "$(_wr_header "$hdrs" FILE)"
assert_equals "RUN header parsed"  "./tidy.sh downloads" "$(_wr_header "$hdrs" RUN)"
assert_equals "an absent header reads as empty" "" "$(_wr_header "$hdrs" MODE)"
assert_file_not_contains "'# Run it twice' (space after #) is a comment, not a header" "Run it twice" "$hdrs"
# the body is everything after the LAST header up to #DATA (the blank line before #DATA included)
assert_equals "body first line is the shebang (the line after the last header)" '#!/usr/bin/env bash' "$(head -1 "$body")"
assert_equals "body is 3 lines: shebang, echo, the blank before #DATA" "3" "$(wc -l < "$body")"
assert_file_not_contains "narration is not in the body"  "narration above" "$body"
assert_file_not_contains "headers are not in the body"   "#FILE"           "$body"
assert_file_not_contains "#DATA marker not in the body"  "#DATA"           "$data"
assert_file_contains     "data after #DATA"              "line two"        "$data"
assert_file_not_contains "body does not contain the data" "line one"       "$body"

# --- test: case-insensitive keys, colon form, trailing space, last header wins ---
: > "$body"; : > "$data"; : > "$hdrs"
cat > "$in" <<'EOF'
#day: 3
#file  lower.sh
#mode 644
#Mode 600
#timeout 5
#fresh yes
echo hi
EOF
_wr_divide "$in" "$body" "$data" "$hdrs"
assert_equals "lower-case '#day:' is a DAY header"        "3"        "$(_wr_header "$hdrs" DAY)"
assert_equals "trailing whitespace trimmed from FILE"     "lower.sh" "$(_wr_header "$hdrs" FILE)"
assert_equals "the last MODE header wins"                 "600"      "$(_wr_header "$hdrs" MODE)"
assert_equals "TIMEOUT header parsed"                     "5"        "$(_wr_header "$hdrs" TIMEOUT)"
assert_equals "FRESH header parsed"                       "yes"      "$(_wr_header "$hdrs" FRESH)"
assert_equals "body is the one line after the headers"    "echo hi"  "$(cat "$body")"
assert_empty  "no #DATA: data file empty"                 "$data"

# --- test: no headers at all -> no body (nothing to write), hdrs empty ---
: > "$body"; : > "$data"; : > "$hdrs"
printf '# just a comment\necho nothing\n' > "$in"
_wr_divide "$in" "$body" "$data" "$hdrs"
assert_empty "no headers: hdrs file empty" "$hdrs"
assert_empty "no headers: body file empty (nothing would be written)" "$body"

# --- sourcing the script must not return failure (set -e callers) ---
assert_equals "sourcing workoutrepl returns 0" "0" \
    "$(bash -c 'source "$1"' _ "$WORKOUTREPL" >/dev/null 2>&1; echo $?)"

summary
