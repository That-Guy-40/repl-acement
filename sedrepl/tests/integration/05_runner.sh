#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$SEDREPL"

replfile=$(mktemp /tmp/sedrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_sedrepl_setup "$replfile"

# --- test: substitution + #DATA → runner shows sed command and substituted text ---
cat > "$replfile" <<'EOF'
s/hello/world/g

#DATA
hello there
say hello
EOF

assert_output_contains "runner shows sed in command header" "# command:  sed" "$REPL_RUNNER"
assert_output_contains "substitution result appears in output" "world there" "$REPL_RUNNER"

# --- test: #ARGS -n with /p → only matching lines printed ---
cat > "$replfile" <<'EOF'
#ARGS -n
/^keep/p

#DATA
keep this line
drop this line
keep another
EOF

assert_output_contains "#ARGS -n filters to matching lines only" "keep this line" "$REPL_RUNNER"
assert_output_contains "#ARGS -n suppresses non-matching lines (only keep lines)" "keep another" "$REPL_RUNNER"

summary
