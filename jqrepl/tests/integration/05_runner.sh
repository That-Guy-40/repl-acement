#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$JQREPL"

replfile=$(mktemp /tmp/jqrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_jqrepl_setup "$replfile"

# --- test: filter + #DATA → runner shows jq command and extracted value ---
cat > "$replfile" <<'EOF'
.name

#DATA
{"name": "alice", "age": 30}
EOF

assert_output_contains "runner shows jq in command header" "# command:  jq" "$REPL_RUNNER"
assert_output_contains "field extraction returns correct value" "alice" "$REPL_RUNNER"

# --- test: no #DATA → null-input mode, -n appears in command ---
cat > "$replfile" <<'EOF'
1 + 1
EOF

assert_output_contains "no-data mode shows -n in command header" "jq -n" "$REPL_RUNNER"
assert_output_contains "null-input expression evaluates correctly" "2" "$REPL_RUNNER"

# --- test: #ARGS -r → raw string output (no JSON quotes) ---
cat > "$replfile" <<'EOF'
#ARGS -r
.city

#DATA
{"city": "Springfield"}
EOF

assert_output_contains "#ARGS -r produces raw string output without quotes" "Springfield" "$REPL_RUNNER"

summary
