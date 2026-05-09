#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/03_basic_filter.sh - verify yq executes expressions correctly
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

assert_command_found "yq is available" yq

data=$(mktemp)
trap 'rm -f "$data"' EXIT

cat > "$data" <<'EOF'
- name: Alice
  age: 30
- name: Bob
  age: 17
EOF

assert_output_equals \
    "yq field extraction" \
    "Alice
Bob" \
    yq eval '.[] | .name' "$data"

assert_output_equals \
    "yq select filter" \
    "Alice" \
    yq eval '.[] | select(.name == "Alice") | .name' "$data"

assert_output_equals \
    "yq null-input expression" \
    "hello" \
    yq eval --null-input '"hello"'

summary
