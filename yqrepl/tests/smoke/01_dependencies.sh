#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/01_dependencies.sh - verify required tools are present
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/../helpers.sh"

assert_command_found "yq is available"   yq
assert_command_found "tmux is available" tmux
assert_command_found "entr is available" entr
assert_command_found "xargs is available" xargs

# yqrepl targets Mike Farah's Go yq (github.com/mikefarah/yq); the unrelated
# Python "yq" (a jq wrapper) has a different grammar and will not work.
if command -v yq > /dev/null 2>&1; then
    if yq --version 2>&1 | grep -qi 'mikefarah'; then
        pass "yq is Mike Farah's Go yq (the flavor yqrepl targets)"
    else
        fail "yq on PATH is not Mike Farah's Go yq" \
             "got: $(yq --version 2>&1 | head -1) — install from https://github.com/mikefarah/yq"
    fi
fi

summary
