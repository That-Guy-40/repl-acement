#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/06_examples_file.sh - validate examples.sed runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEDREPL="$TESTS_DIR/../../sedrepl"
EXAMPLES="$TESTS_DIR/../../examples.sed"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$SEDREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_sedrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows sed command header" "# command:  sed" "$REPL_RUNNER"
assert_output_contains "examples file: s/chr/chromosome/ substitution works" "chromosome1" "$REPL_RUNNER"

summary
