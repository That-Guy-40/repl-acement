#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
##
##  smoke/04_makefile.sh - `make help` works, and `make publish` pushes only to
##  the Docker Hub account given in DOCKER_HUB_USER (a fake docker records
##  the calls, so nothing is ever really pushed).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"

if ! command -v make > /dev/null 2>&1; then
    echo "  SKIP: make not installed"
    exit 0
fi

help=$(make -s -C "$DIR" help 2>&1); rc=$?
assert_equals "make help exits 0" "0" "$rc"
if [[ $help == *"make publish"* && $help == *"make test"* ]]; then
    pass "make help lists the targets"
else
    fail "make help does not list the targets" "$help"
fi

fake=$(mktemp -d); log="$fake/calls"
trap 'rm -rf "$fake"' EXIT
printf '#!/bin/sh\necho "$*" >> "%s"\n' "$log" > "$fake/docker"
chmod +x "$fake/docker"

out=$(env -u DOCKER_HUB_USER PATH="$fake:$PATH" make -s -C "$DIR" publish 2>&1); rc=$?
assert_equals "publish without DOCKER_HUB_USER fails" "2" "$rc"
if [[ $out == *DOCKER_HUB_USER* ]]; then
    pass "…and says to set DOCKER_HUB_USER"
else
    fail "…without naming DOCKER_HUB_USER" "$out"
fi
if [[ ! -e $log ]]; then
    pass "…and never calls docker"
else
    fail "…but called docker anyway" "$(cat "$log")"
fi

out=$(PATH="$fake:$PATH" make -s -C "$DIR" publish DOCKER_HUB_USER=someone 2>&1); rc=$?
assert_equals "publish with DOCKER_HUB_USER succeeds" "0" "$rc"
assert_equals "it tags and pushes someone/mlrrepl" \
    "tag mlrrepl someone/mlrrepl
push someone/mlrrepl" "$(cat "$log" 2>/dev/null)"

summary
