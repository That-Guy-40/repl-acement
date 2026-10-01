#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/07_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

replfile=$(mktemp /tmp/mlrrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}" "${REPL_EDITPANE:-}"' EXIT

_mlrrepl_setup "$replfile"

# --- test: CSV data auto-detected → runner shows mlr --csv in command ---
cat > "$replfile" <<'EOF'
$total = $price * $qty

#DATA
name,price,qty
apple,1.5,10
banana,0.75,20
EOF

assert_output_contains "CSV data auto-detected in command header" "# command:  mlr --csv" "$REPL_RUNNER"
assert_output_contains "computed field appears in CSV output" "15" "$REPL_RUNNER"

# --- test: JSONL data auto-detected → runner shows mlr --jsonl in command ---
cat > "$replfile" <<'EOF'
$x = $x + 1

#DATA
{"x": 41}
EOF

assert_output_contains "JSONL data auto-detected in command header" "# command:  mlr --jsonl" "$REPL_RUNNER"

# --- test: no #DATA → runner shows no #DATA section message ---
cat > "$replfile" <<'EOF'
$x = $x * 2
EOF

assert_output_contains "no #DATA section produces helpful message" "no #DATA section" "$REPL_RUNNER"

summary
