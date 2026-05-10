#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/08_examples_file.sh - validate examples.awk runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWKREPL="$TESTS_DIR/../../awkrepl"
EXAMPLES="$TESTS_DIR/../../examples.awk"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$AWKREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_HELPERS:-}" "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_awkrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows gawk command header" "# command:  gawk" "$REPL_RUNNER"
assert_output_contains "examples file: default 'print' outputs input lines" "chr1" "$REPL_RUNNER"

summary
