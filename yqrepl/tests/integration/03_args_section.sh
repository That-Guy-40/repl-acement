#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016,SC2046
##  integration/03_args_section.sh - #ARGS flags are forwarded to yq
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: --tojson (-j) produces JSON output ---
# yq 4.2.x uses -j / --tojson; later versions use -o json
cat > "$replfile" <<'EOF'
#ARGS -j
.[] | .name

#DATA
- name: Alice
- name: Bob
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS -j written to args file" '-j' "$args"

_expr=$(cat "$src")
output=$(yq eval $(cat "$args") "$_expr" "$data")

# JSON output wraps strings in quotes
if echo "$output" | grep -qF '"Alice"'; then
    pass "-j flag produces JSON-quoted strings"
else
    fail "-j flag produces JSON-quoted strings" "got: $output"
fi

summary
