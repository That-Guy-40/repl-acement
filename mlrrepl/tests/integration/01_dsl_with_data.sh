#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/01_dsl_with_data.sh - full pipeline: DSL + #DATA → output
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

if ! command -v mlr > /dev/null 2>&1; then
    pass "mlr not installed — skipping integration tests"
    summary
    exit 0
fi

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: computed field ---
cat > "$replfile" <<'EOF'
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
output=$(mlr --csv put -f "$src" "$data")
if echo "$output" | grep -qF 'total'; then
    pass "computed field appears in output"
else
    fail "computed field appears in output" "got: $output"
fi

# --- test: filter expression ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
filter $quantity > 3

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
cherries,12,3.00
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
output=$(mlr --csv put -f "$src" "$data")
assert_output_contains "filter keeps high-quantity rows" "bananas" \
    mlr --csv put -f "$src" "$data"

if echo "$output" | grep -qF 'apples'; then
    fail "filter removes low-quantity rows" "apples should be filtered out"
else
    pass "filter removes low-quantity rows"
fi

# --- test: string concatenation ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
$label = $name . " x" . $quantity

#DATA
name,quantity
apples,3
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
output=$(mlr --csv put -f "$src" "$data")
if echo "$output" | grep -qF 'apples x3'; then
    pass "string concatenation in DSL"
else
    fail "string concatenation in DSL" "got: $output"
fi

summary
