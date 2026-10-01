#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/01_dependencies.sh - verify required tools are present
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

echo "Checking required dependencies..."

assert_command_found "jq is in PATH"   jq
assert_command_found "tmux is in PATH" tmux
assert_command_found "entr is in PATH" entr
assert_command_found "xargs is in PATH" xargs
assert_command_found "sed is in PATH"  sed

echo ""
echo "Checking optional dependencies..."

if command -v bat > /dev/null 2>&1 || command -v batcat > /dev/null 2>&1; then
    pass "bat (or batcat) is available (syntax highlighting enabled)"
else
    echo "  SKIP: neither bat nor batcat found (syntax highlighting will be disabled)"
fi

summary
