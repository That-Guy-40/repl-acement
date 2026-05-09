#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/01_dependencies.sh - verify required tools are present
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

echo "Checking required dependencies..."

assert_command_found "sed is in PATH"  sed
assert_command_found "tmux is in PATH" tmux
assert_command_found "entr is in PATH" entr

echo ""
echo "Checking optional dependencies..."

if command -v bat > /dev/null 2>&1; then
    pass "bat is available (syntax highlighting enabled)"
else
    echo "  SKIP: bat not found (syntax highlighting will be disabled)"
fi

summary
