#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/06_examples_file.sh - validate examples.jq runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQREPL="$TESTS_DIR/../../jqrepl"
EXAMPLES="$TESTS_DIR/../../examples.jq"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$JQREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_jqrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows jq command header" "# command:  jq" "$REPL_RUNNER"
assert_output_contains "examples file: .[] | .name extracts first name" "Alice" "$REPL_RUNNER"

summary
