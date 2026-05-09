#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_multi_statement.sh
##
##  Miller DSL supports multiple statements in a single put file, separated
##  by semicolons or newlines.  This exercises multi-line DSL files.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- multiple assignments on separate lines (Miller 6 requires semicolons) ---
cat > "$replfile" <<'EOF'
$total = $quantity * $price;
$label = $name . " x" . string($quantity)

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
output=$(mlr --csv put -f "$src" "$data")

if echo "$output" | grep -qF 'total' && echo "$output" | grep -qF 'label'; then
    pass "multi-line DSL adds both computed fields"
else
    fail "multi-line DSL adds both computed fields" "got: $output"
fi

if echo "$output" | grep -qF 'apples x3'; then
    pass "label field uses string concatenation correctly"
else
    fail "label field uses string concatenation correctly" "got: $output"
fi

# --- conditional logic across multiple lines ---
: > "$src"; : > "$data"; : > "$args"
cat > "$replfile" <<'EOF'
$total = $quantity * $price;
if ($total > 5) {
  $tier = "bulk"
} else {
  $tier = "small"
}

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
cherries,12,3.00
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
output=$(mlr --csv put -f "$src" "$data")

if echo "$output" | grep -qF 'tier'; then
    pass "multi-line conditional DSL adds tier field"
else
    fail "multi-line conditional DSL adds tier field" "got: $output"
fi

# cherries: 12 * 3.00 = 36 > 5 → bulk
if echo "$output" | grep 'cherries' | grep -qF 'bulk'; then
    pass "cherries correctly classified as bulk"
else
    fail "cherries correctly classified as bulk" "got: $output"
fi

# apples: 3 * 1.20 = 3.60 < 5 → small
if echo "$output" | grep 'apples' | grep -qF 'small'; then
    pass "apples correctly classified as small"
else
    fail "apples correctly classified as small" "got: $output"
fi

summary
