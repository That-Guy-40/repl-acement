#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  integration/04_auto_wrap.sh
##
##  awkrepl asks gawk (parse only) whether the comment-stripped source parses
##  as written and/or wrapped. A bare statement such as 'print $1' only parses
##  wrapped, so it is wrapped:
##    - in '{ }' when #DATA is present (runs per-line)
##    - in 'END { }' when #DATA is absent (runs once, on empty input)
##  Rules, functions and BEGIN/END only parse as written and are left alone;
##  a bare expression parses both ways and is judged by how it starts.
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


# --- valid AWK as written is never wrapped, whatever its first line ---
# (the old heuristic only looked at the first line, and wrapped these)
not_wrapped() {  # DESC PROGRAM DATA EXPECTED-OUTPUT
    local desc=$1 prog=$2 rows=$3 want=$4
    : > "$src"; : > "$data"; : > "$args"
    printf '%s\n\n#DATA\n%s\n' "$prog" "$rows" > "$replfile"
    _awkrepl_divide "$replfile" "$src" "$data" "$args"
    if [[ $(head -1 "$src") == '{' || $(head -1 "$src") == 'END {' ]]; then
        fail "$desc: was wrapped" "$(cat "$src")"
    else
        pass "$desc: not wrapped"
    fi
    assert_equals "$desc: output" "$want" "$(gawk -f "$src" "$data")"
}
not_wrapped "negated regex !/re/"      '!/^foo/'                   $'foo\nbar\nbaz'  $'bar\nbaz'
not_wrapped "\$NF pattern"             '$NF > 4'                   $'a 3\nb 5'      'b 5'
not_wrapped "dedupe idiom !seen[]++"   '!seen[$1]++'               $'x\ny\nx'       $'x\ny'
not_wrapped "function definition"      $'function dbl(n) { return n * 2 }\n{ print dbl($1) }' $'2\n5' $'4\n10'
not_wrapped "length() pattern"         'length($0) > 3'            $'ab\nabcd'      'abcd'
# a bare NR/NF/FNR/FILENAME expression is a pattern even without an operator
not_wrapped "bare NF pattern"            'NF'                        $'a b\n\nc'      $'a b\nc'
not_wrapped "NR arithmetic pattern"      'NR % 2'                    $'a\nb\nc'       $'a\nc'

# --- code that doesn't parse either way is left as written ---
: > "$src"; : > "$data"; : > "$args"
printf '{ print $1\n' > "$replfile"
_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_equals "unparseable code is left as written (no wrapping)" '{ print $1' "$(cat "$src")"

# --- a bare expression that reads as a statement is still wrapped, even though
#     it would also parse as a pattern (e.g. the printa() helper idiom) ---
wrapped_as() {  # DESC PROGRAM DATA OPENER EXPECTED-OUTPUT (substring; '' = no output)
    local desc=$1 prog=$2 rows=$3 opener=$4 want=$5 out
    : > "$src"; : > "$data"; : > "$args"
    if [[ -n $rows ]]; then
        printf '%s\n\n#DATA\n%s\n' "$prog" "$rows" > "$replfile"
    else
        printf '%s\n' "$prog" > "$replfile"
    fi
    _awkrepl_divide "$replfile" "$src" "$data" "$args"
    assert_equals "$desc: wrapped in '$opener'" "$opener" "$(head -1 "$src")"
    out=$(gawk -f "$helpers" -f "$src" "$data" 2>&1)
    if [[ -z $want && -z $out ]] || [[ -n $want && $out == *"$want"* ]]; then
        pass "$desc: output"
    else
        fail "$desc: output" "wanted '$want' in: $out"
    fi
}
helpers=$(mktemp); echo "$AWKHELPERS" > "$helpers"
wrapped_as "printa() helper idiom, no #DATA" 'n = split("a b c", arr); printa(arr)' '' 'END {' 'noname[2]=b'
wrapped_as "bare assignment, no #DATA"       'x = 6 * 7'                            '' 'END {' ''
wrapped_as "counter, with #DATA"             'n++'                                  $'a\nb' '{'  ''
wrapped_as "function call, with #DATA"       'printf("<%s>\n", $1)'                 $'a\nb' '{'  '<a>'
wrapped_as "'<' or '>' inside a string"      's = "<td>" $1 "</td>"'                $'a\nb' '{'  ''
rm -f "$helpers"

summary
