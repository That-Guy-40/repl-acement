#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/01_dependencies.sh - verify required tools are present, and that the
##  vendored trainer (workout/bin/workout) answers the two plumbing verbs the
##  REPL calls on every save.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"

assert_command_found "tmux is available" tmux
assert_command_found "entr is available" entr
assert_command_found "sed is available" sed
assert_command_found "awk is available" awk
assert_command_found "timeout (coreutils) is available" timeout

WORKOUT="$DIR/workout/bin/workout"
if [[ -x "$WORKOUT" ]]; then
    pass "the vendored trainer workout/bin/workout is executable"
else
    fail "workout/bin/workout is missing or not executable" "$WORKOUT"
fi
assert_output_equals "workout --day-number boss1 resolves to 7" "7" "$WORKOUT" --day-number boss1
assert_output_equals "workout --day-number day30 resolves to 30" "30" "$WORKOUT" --day-number day30
title=$("$WORKOUT" --title 7 2>&1)
if [[ -n "$title" ]]; then
    pass "workout --title 7 prints a title ($title)"
else
    fail "workout --title 7 printed nothing"
fi
"$WORKOUT" --day-number 31 >/dev/null 2>&1; rc=$?
if (( rc != 0 )); then
    pass "workout --day-number 31 is refused (rc=$rc)"
else
    fail "workout --day-number 31 was accepted"
fi
n=$(find "$DIR/workout/drills" -name 'day[0-9][0-9].sh' | wc -l)
assert_equals "30 drills are vendored under workout/drills" "30" "$n"

summary
