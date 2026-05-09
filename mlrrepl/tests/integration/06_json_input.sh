#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016,SC2046
##  integration/06_json_input.sh
##
##  JSONL input is auto-detected from the data header; JSON output can be
##  requested via #ARGS --jsonl (it's also the default when input is JSONL).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- JSONL input auto-detected, computed field added ---
cat > "$replfile" <<'EOF'
$grade = ($score >= 90) ? "A" : "B"

#DATA
{"name":"Alice","score":95}
{"name":"Bob","score":72}
{"name":"Carol","score":88}
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
fmt=$(_mlrrepl_detect_format "$data")
assert_equals "JSONL data auto-detected" '--jsonl' "$fmt"

output=$(mlr "$fmt" put -f "$src" "$data")
if echo "$output" | grep -q '"Alice"' && echo "$output" | grep -q '"grade"'; then
    pass "JSONL input produces JSON output with computed field"
else
    fail "JSONL input produces JSON output with computed field" "got: $output"
fi

# Alice: score 95 >= 90 → A
if echo "$output" | grep '"Alice"' | grep -q '"A"'; then
    pass "Alice gets grade A"
else
    fail "Alice gets grade A" "got: $(echo "$output" | grep 'Alice')"
fi

# Bob: score 72 < 90 → B
if echo "$output" | grep '"Bob"' | grep -q '"B"'; then
    pass "Bob gets grade B"
else
    fail "Bob gets grade B" "got: $(echo "$output" | grep 'Bob')"
fi

# --- explicit #ARGS --jsonl overrides CSV auto-detection ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
#ARGS --jsonl
$total = $quantity * $price

#DATA
{"name":"apples","quantity":3,"price":1.20}
{"name":"bananas","quantity":5,"price":0.50}
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS --jsonl written to args file" '--jsonl' "$args"

output=$(mlr $(cat "$args") put -f "$src" "$data")
if echo "$output" | grep -q '"total"'; then
    pass "explicit #ARGS --jsonl processes JSONL data"
else
    fail "explicit #ARGS --jsonl processes JSONL data" "got: $output"
fi

summary
