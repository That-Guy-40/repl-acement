#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/01_filter_with_data.sh - full pipeline: expression + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"

# yqrepl targets Mike Farah's Go yq; skip cleanly on any other (or missing) yq
if ! { command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qi mikefarah; }; then
    echo "  SKIP: yq on PATH is not Mike Farah's Go yq (yqrepl targets that one)"; exit 0
fi
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: field extraction ---
cat > "$replfile" <<'EOF'
.[] | .name

#DATA
- name: Alice
  age: 30
- name: Bob
  age: 17
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
_expr=$(cat "$src")
output=$(yq eval "$_expr" "$data")
assert_equals "field extraction from YAML list" \
    "Alice
Bob" "$output"

# --- test: select filter ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
.[] | select(.city == "Chicago") | .name

#DATA
- name: Alice
  city: New York
- name: Bob
  city: Boston
- name: Carol
  city: Chicago
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
_expr=$(cat "$src")
output=$(yq eval "$_expr" "$data")
assert_equals "select filter passes only Chicago residents" "Carol" "$output"

# --- test: nested field access ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
.metadata.name

#DATA
metadata:
  name: my-service
  namespace: production
spec:
  replicas: 3
EOF

_yqrepl_divide "$replfile" "$src" "$data" "$args"
_expr=$(cat "$src")
output=$(yq eval "$_expr" "$data")
assert_equals "nested field access" "my-service" "$output"

summary
