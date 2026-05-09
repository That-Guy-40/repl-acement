#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/03_basic_dsl.sh - verify mlr executes DSL expressions correctly
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

if ! command -v mlr > /dev/null 2>&1; then
    pass "mlr not installed — skipping DSL execution tests"
    summary
    exit 0
fi

assert_command_found "mlr is available" mlr

src=$(mktemp); data=$(mktemp)
trap 'rm -f "$src" "$data"' EXIT

cat > "$data" <<'EOF'
name,quantity,price
apples,3,1.20
bananas,5,0.50
EOF

echo '$total = $quantity * $price' > "$src"
output=$(mlr --csv put -f "$src" "$data")
if echo "$output" | grep -qF 'total'; then
    pass "mlr put -f adds computed field"
else
    fail "mlr put -f adds computed field" "got: $output"
fi

echo 'filter $quantity > 3' > "$src"
output=$(mlr --csv put -f "$src" "$data")
if echo "$output" | grep -qF 'bananas' && ! echo "$output" | grep -qF 'apples'; then
    pass "mlr put filter keeps only matching rows"
else
    fail "mlr put filter keeps only matching rows" "got: $output"
fi

summary
