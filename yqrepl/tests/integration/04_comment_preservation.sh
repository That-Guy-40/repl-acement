#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/04_comment_preservation.sh
##
##  yqrepl preserves # comments in the source — unlike awkrepl, which strips
##  them.  yq supports YAML comments natively, and comments in the expression
##  file act as documentation without interfering with evaluation.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- inline comment lines are preserved ---
cat > "$replfile" <<'EOF'
# select by city
.[] | select(.city == "Boston") | .name

#DATA
- name: Alice
  city: New York
- name: Bob
  city: Boston
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "inline comment preserved in src"  '# select by city'              "$src"
assert_file_contains "active expression also present"   '.[] | select(.city == "Boston")' "$src"

# yq ignores # comments; the expression still runs correctly
# we strip the comment line before evaluating so the file contains only the expression
_expr=$(grep -v '^#' "$src")
output=$(yq eval "$_expr" "$data")
assert_equals "commented expression still runs correctly" "Bob" "$output"

# --- commented-out expressions are preserved (not stripped) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
# .[] | .name
.[] | .city

#DATA
- name: Alice
  city: New York
- name: Bob
  city: Boston
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains     "commented-out expression preserved" '# .[] | .name'  "$src"
assert_file_contains     "active expression present"          '.[] | .city'    "$src"

_expr=$(grep -v '^#' "$src" | grep -v '^[[:space:]]*$')
output=$(yq eval "$_expr" "$data")
assert_equals "only active (non-commented) expression runs" \
    "New York
Boston" "$output"

summary
