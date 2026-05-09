#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_comment_stripping.sh
##
##  awkrepl strips # comments and blank lines from the source before
##  passing it to gawk — unlike sedrepl and jqrepl, which leave comments
##  intact (both sed and jq support them natively in script files).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- inline comment lines are stripped ---
cat > "$replfile" <<'EOF'
# count lines
END { print NR }
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "inline comment stripped"        '# count lines'    "$src"
assert_file_contains     "AWK code survives strip"        'END { print NR }' "$src"

# --- commented-out code is also stripped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
# { print $1 }
{ print $2 }

#DATA
hello world
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_not_contains "commented-out code stripped"  '# { print $1 }' "$src"
assert_file_contains     "active code remains"          '{ print $2 }'   "$src"

output=$(gawk -f "$src" "$data")
assert_equals "only active (non-commented) code runs" "world" "$output"

# --- blank lines between code are stripped ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
{ a[$1]++ }

END { for (k in a) print k, a[k] }

#DATA
x
y
x
EOF

_awkrepl_divide "$replfile" "$src" "$data" "$args"
# blank lines gone; the AWK code should still be syntactically valid
assert_command_found "gawk is available" gawk
output=$(gawk -f "$src" "$data" | sort)
assert_equals "blank-stripped multi-block script runs correctly" \
    "x 2
y 1" "$output"

summary
