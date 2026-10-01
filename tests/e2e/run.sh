#!/usr/bin/env bash
##
##  tests/e2e/run.sh - run all end-to-end (live tmux UI) tests
##
##  These drive each REPL's real three-pane tmux session with the vendored
##  ttydrive (tests/lib/ttydrive) and check that the entr event loop reacts
##  to edits. They need tmux + entr + the relevant tool; a suite that finds
##  its tool missing prints SKIP and passes.
##

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

for t in "$TESTS_DIR"/[0-9]*.sh; do
    echo "==> $(basename "$t")"
    if bash "$t"; then
        (( PASS++ )) || true
    else
        (( FAIL++ )) || true
    fi
    echo ""
done

echo "e2e: $PASS suites passed, $FAIL suites failed"
(( FAIL == 0 ))
