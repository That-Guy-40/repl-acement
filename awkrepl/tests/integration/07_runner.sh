#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/07_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

replfile=$(mktemp /tmp/awkrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_HELPERS:-}" "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_awkrepl_setup "$replfile"

# --- test: pattern/action + #DATA → runner shows gawk command and result ---
cat > "$replfile" <<'EOF'
/^chr/ { print $1, $3 }

#DATA
chr1	100	200
chr8	50	75
EOF

assert_output_contains "runner shows gawk in command header" "# command:  gawk" "$REPL_RUNNER"

assert_output_contains "runner extracts correct field value" "200" "$REPL_RUNNER"

# --- test: bare expression without #DATA → END{}-wrapped result ---
cat > "$replfile" <<'EOF'
print 6 * 7
EOF

assert_output_contains "no-data expression wrapped in END{} yields result" "42" "$REPL_RUNNER"

# --- test: #ARGS -v → arg appears in command header and variable is used ---
cat > "$replfile" <<'EOF'
{ print x }

#ARGS -v x=hello
#DATA
ignored
EOF

assert_output_contains "#ARGS -v appears in command header" "-v x=hello" "$REPL_RUNNER"
assert_output_contains "#ARGS -v variable value is printed" "hello" "$REPL_RUNNER"

summary
