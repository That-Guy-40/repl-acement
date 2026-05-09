#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  smoke/02_divide.sh - unit tests for _mlrrepl_divide
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

src=$(mktemp); data=$(mktemp); args=$(mktemp); in=$(mktemp)
trap 'rm -f "$src" "$data" "$args" "$in"' EXIT

# --- test: Miller DSL + #DATA split ---
cat > "$in" <<'EOF'
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
EOF

_mlrrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "DSL ends up in src"               '$total = $quantity * $price' "$src"
assert_file_not_contains "#DATA marker removed from src"    '#DATA'                       "$src"
assert_file_contains     "data ends up in data file"        'apples'                      "$data"
assert_file_not_contains "#DATA marker removed from data"   '#DATA'                       "$data"

# --- test: no #DATA section ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
$rank = NR
EOF

_mlrrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "DSL in src when no #DATA"   '$rank = NR' "$src"
assert_empty         "data file empty when no #DATA" "$data"

# --- test: comments are preserved (mlr supports # natively) ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
# compute total revenue
$total = $quantity * $price
EOF

_mlrrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains "comments preserved in src"          '# compute total revenue'      "$src"
assert_file_contains "active DSL remains after comment"   '$total = $quantity * $price'  "$src"

# --- test: #ARGS extraction ---
: > "$src"; : > "$data"; : > "$args"
cat > "$in" <<'EOF'
#ARGS --tsv
$total = $quantity * $price

#DATA
name	quantity	price
apples	3	1.20
EOF

_mlrrepl_divide "$in" "$src" "$data" "$args"

assert_file_contains     "#ARGS value written to args file" '--tsv'  "$args"
assert_file_not_contains "#ARGS line removed from src"      '#ARGS'  "$src"

summary
