#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016,SC2046
##  integration/02_args_section.sh - #ARGS flags are forwarded to mlr
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

if ! command -v mlr > /dev/null 2>&1; then
    echo "  SKIP: mlr not installed (#ARGS tests)"
    exit 0
fi

replfile=$(mktemp)
src=$(mktemp); data=$(mktemp); args=$(mktemp)
trap 'rm -f "$replfile" "$src" "$data" "$args"' EXIT

# --- test: --tsv flag processes TSV data ---
cat > "$replfile" <<'EOF'
#ARGS --tsv
$total = $quantity * $price

#DATA
name	quantity	price
apples	3	1.20
EOF

_mlrrepl_divide "$replfile" "$src" "$data" "$args"
assert_file_contains "#ARGS --tsv written to args file" '--tsv' "$args"

output=$(mlr $(cat "$args") put -f "$src" "$data")
if echo "$output" | grep -qF 'total'; then
    pass "--tsv flag processes tab-separated data"
else
    fail "--tsv flag processes tab-separated data" "got: $output"
fi

summary
