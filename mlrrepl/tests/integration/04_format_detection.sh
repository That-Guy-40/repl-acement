#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/04_format_detection.sh
##
##  _mlrrepl_detect_format sniffs the first line of the data file and picks
##  --csv, --jsonl, or --nidx so the runner doesn't need an explicit #ARGS
##  for the common cases.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

data=$(mktemp)
trap 'rm -f "$data"' EXIT

# --- CSV: comma in first line → --csv ---
printf 'name,quantity,price\napples,3,1.20\n' > "$data"
assert_equals "CSV data detected as --csv" '--csv' "$(_mlrrepl_detect_format "$data")"

# --- JSONL: first line starts with '{' → --jsonl ---
printf '{"name":"Alice","score":95}\n{"name":"Bob","score":72}\n' > "$data"
assert_equals "JSONL data detected as --jsonl" '--jsonl' "$(_mlrrepl_detect_format "$data")"

# --- plain text: no comma or '{' → --nidx ---
printf 'hello world\nfoo bar\n' > "$data"
assert_equals "plain text detected as --nidx" '--nidx' "$(_mlrrepl_detect_format "$data")"

# --- TSV: no comma in first line → --nidx (user must add #ARGS --tsv) ---
printf 'name\tquantity\tprice\napples\t3\t1.20\n' > "$data"
assert_equals "TSV without #ARGS falls back to --nidx" '--nidx' "$(_mlrrepl_detect_format "$data")"

# --- end-to-end: auto-detected --csv runs without explicit #ARGS ---
replfile=$(mktemp); src=$(mktemp); args=$(mktemp)
trap 'rm -f "$data" "$replfile" "$src" "$args"' EXIT

cat > "$replfile" <<'EOF'
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
EOF

source "$MLRREPL"
_mlrrepl_divide "$replfile" "$src" "$data" "$args"
fmt=$(_mlrrepl_detect_format "$data")
assert_equals "auto-detected format for CSV replfile is --csv" '--csv' "$fmt"

output=$(mlr "$fmt" put -f "$src" "$data")
if echo "$output" | grep -qF 'total'; then
    pass "auto-detected --csv produces output with computed field"
else
    fail "auto-detected --csv produces output with computed field" "got: $output"
fi

# --- end-to-end: auto-detected --jsonl processes JSON records ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
$grade = ($score >= 90) ? "A" : "B"

#DATA
{"name":"Alice","score":95}
{"name":"Bob","score":72}
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
fmt=$(_mlrrepl_detect_format "$data")
assert_equals "auto-detected format for JSONL replfile is --jsonl" '--jsonl' "$fmt"

output=$(mlr "$fmt" put -f "$src" "$data")
if echo "$output" | grep -q '"grade"'; then
    pass "auto-detected --jsonl produces output with computed field"
else
    fail "auto-detected --jsonl produces output with computed field" "got: $output"
fi

summary
