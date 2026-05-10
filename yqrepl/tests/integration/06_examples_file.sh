#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/06_examples_file.sh - validate examples.yq runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$TESTS_DIR/../../yqrepl"
EXAMPLES="$TESTS_DIR/../../examples.yq"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$YQREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_yqrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows yq eval command header" "# command:  yq eval" "$REPL_RUNNER"
assert_output_contains "examples file: .[] | .name extracts first name" "Alice" "$REPL_RUNNER"

summary
