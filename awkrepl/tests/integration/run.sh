#!/usr/bin/env bash
##
##  tests/integration/run.sh - run all integration tests
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

echo "integration: $PASS suites passed, $FAIL suites failed"
(( FAIL == 0 ))
