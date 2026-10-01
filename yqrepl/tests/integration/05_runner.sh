#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
source "$TESTS_DIR/../helpers.sh"

# yqrepl targets Mike Farah's Go yq; skip cleanly on any other (or missing) yq
if ! { command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qi mikefarah; }; then
    echo "  SKIP: yq on PATH is not Mike Farah's Go yq (yqrepl targets that one)"; exit 0
fi
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

replfile=$(mktemp /tmp/yqrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}" "${REPL_EDITPANE:-}"' EXIT

_yqrepl_setup "$replfile"

# --- test: expression + YAML #DATA → runner shows yq eval command and extracted value ---
cat > "$replfile" <<'EOF'
.name

#DATA
name: alice
age: 30
EOF

assert_output_contains "runner shows yq eval in command header" "# command:  yq eval" "$REPL_RUNNER"
assert_output_contains "field extraction returns correct value" "alice" "$REPL_RUNNER"

# --- test: no #DATA → null-input mode, --null-input appears in command ---
cat > "$replfile" <<'EOF'
{"answer": 42} | .answer
EOF

assert_output_contains "no-data mode shows --null-input in command header" "--null-input" "$REPL_RUNNER"

summary
