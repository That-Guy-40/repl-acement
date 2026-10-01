#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/03_comment_preservation.sh
##
##  mlrrepl preserves # comments in the source — unlike awkrepl which strips
##  them.  Miller supports # comments in DSL files natively.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

if ! command -v mlr > /dev/null 2>&1; then
    echo "  SKIP: mlr not installed (comment preservation tests)"
    exit 0
fi

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- inline comment lines are preserved ---
cat > "$replfile" <<'EOF'
# compute total revenue per item
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "inline comment preserved in src" '# compute total revenue' "$src"
assert_file_contains "active DSL also present"         '$total = $quantity * $price' "$src"

# mlr supports # comments in DSL files; the expression runs correctly with them
output=$(mlr --csv put -f "$src" "$data")
if echo "$output" | grep -qF 'total'; then
    pass "DSL with comment still executes correctly"
else
    fail "DSL with comment still executes correctly" "got: $output"
fi

summary
