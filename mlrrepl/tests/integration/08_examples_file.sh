#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091,SC2016
##  integration/08_examples_file.sh - validate examples.mlr runs without errors
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MLRREPL="$TESTS_DIR/../../mlrrepl"
EXAMPLES="$TESTS_DIR/../../examples.mlr"
source "$TESTS_DIR/../helpers.sh"
cd "$TESTS_DIR/../.." || exit 1
source "$MLRREPL"

trap 'rm -f "${REPL_SRC:-}" "${REPL_DATA:-}" "${REPL_ARGS:-}" \
    "${REPL_RUNNER:-}" "${REPL_FORMATTER:-}" "${REPL_CLEANUP:-}"' EXIT

_mlrrepl_setup "$EXAMPLES"

assert_output_contains "examples file shows mlr --csv command header" "# command:  mlr --csv" "$REPL_RUNNER"
assert_output_contains "examples file: \$total field appears in output" "total" "$REPL_RUNNER"

summary
