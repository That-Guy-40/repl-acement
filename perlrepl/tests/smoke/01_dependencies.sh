#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/01_dependencies.sh - verify required tools are present
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

assert_command_found "perl is available" perl
assert_command_found "tmux is available" tmux
assert_command_found "entr is available" entr

summary
