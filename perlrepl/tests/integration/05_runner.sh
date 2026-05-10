#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/05_runner.sh - runner script generation and end-to-end execution
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

replfile=$(mktemp /tmp/perlrepl-test-XXXXXX)
trap 'rm -f "$replfile" "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_perlrepl_setup "$replfile"

# --- test: bare expression + #DATA → runner shows perl command and upcased result ---
cat > "$replfile" <<'EOF'
print uc($_)

#DATA
hello
world
EOF

assert_output_contains "runner shows perl in command header" "# command:  perl" "$REPL_RUNNER"
assert_output_contains "bare expression with data produces upcased output" "HELLO" "$REPL_RUNNER"

# --- test: bare expression + #DATA → -n auto-applied ---
cat > "$replfile" <<'EOF'
print uc($_)

#DATA
hello
EOF

assert_output_contains "bare expression auto-applies -n flag" "-n" "$REPL_RUNNER"

# --- test: full script without data → runner executes and shows result ---
cat > "$replfile" <<'EOF'
my $x = 42;
print "$x\n";
EOF

assert_output_contains "full script without data prints expected value" "42" "$REPL_RUNNER"

# --- test: #ARGS line → arg appears in command header ---
cat > "$replfile" <<'EOF'
print "$name\n"

#ARGS -s -name=testarg
#DATA
ignored
EOF

assert_output_contains "#ARGS content appears in command header" "-s -name=testarg" "$REPL_RUNNER"

summary
