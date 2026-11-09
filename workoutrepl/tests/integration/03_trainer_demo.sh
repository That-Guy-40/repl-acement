#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
##
##  integration/03_trainer_demo.sh - the vendored trainer grades honestly: for
##  each of the 30 drills, workout/demo.sh builds the fixture, requires the
##  checker to FAIL it untouched (the negative control), applies the reference
##  solution and requires the checker to PASS. 60 checks, one verdict line.
##
##  demo.sh exits 77 and names the tools when any a drill needs is missing;
##  that is reported here as SKIP (an unverified run must never read as green).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

out=$(WORKOUT_HOME="$work/w" bash "$DIR/workout/demo.sh" 2>&1); rc=$?
if (( rc == 77 )); then
    echo "  SKIP: $(grep -m1 '^SKIP:' <<<"$out")"
    exit 0
fi
assert_equals "demo.sh exits 0" "0" "$rc"
if grep -q '^PASS: all 60 checks hold' <<<"$out"; then
    pass "every one of the 30 checkers bites on a fresh fixture and passes on its reference solution (60 checks)"
else
    fail "demo.sh did not end on 'PASS: all 60 checks hold'" "$(tail -15 <<<"$out")"
fi

# one day by name, to show the per-day form works too
out=$(WORKOUT_HOME="$work/w2" bash "$DIR/workout/demo.sh" boss1 2>&1); rc=$?
assert_equals "demo.sh boss1 exits 0" "0" "$rc"
if grep -qE '^PASS: all 2 checks hold' <<<"$out"; then
    pass "demo.sh boss1 grades day 7 both ways (2 checks)"
else
    fail "demo.sh boss1 did not report 2 checks" "$(tail -5 <<<"$out")"
fi

# the sandbox is the only thing written: nothing landed in $HOME/workout
if [[ -d "$work/w/day07" && -d "$work/w2/day07" ]]; then
    pass "the demo graded inside the WORKOUT_HOME it was given"
else
    fail "the demo did not use the WORKOUT_HOME it was given" "$(ls "$work" "$work/w" 2>&1)"
fi

summary
