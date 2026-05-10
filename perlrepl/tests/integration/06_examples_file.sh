#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/06_examples_file.sh - validate examples.pl runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERLREPL="$TESTS_DIR/../../perlrepl"
EXAMPLES="$TESTS_DIR/../../examples.pl"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$PERLREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_perlrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows perl command header" "# command:  perl" "$REPL_RUNNER"
assert_output_contains "examples file: chomp+uc upcases input lines" "HELLO WORLD" "$REPL_RUNNER"

summary
