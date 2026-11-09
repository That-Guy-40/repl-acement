#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
##
##  integration/04_verify_walk.sh - the lesson pieces hold up when actually typed
##  into workoutrepl: verify.sh drives walk.sh headlessly (a private tmux
##  server, a throwaway HOME, vim, entr) in BOTH modes — the skeletons must show
##  the named [BAD] lines and never pass a day; the reference bodies must end
##  every day on PASS. verify.sh carries its own negative control (a planted
##  failing row must be reported) and this test requires that control to have run.
##
##  Days 1-3 by default (about 40 s); WORKOUTREPL_DAYS=all walks every piece of
##  every day twice (several minutes).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"

for need in tmux entr vim; do
    if ! command -v "$need" >/dev/null 2>&1; then echo "  SKIP: $need not installed"; exit 0; fi
done

DAYS="${WORKOUTREPL_DAYS:-1-3}"
keep=$(mktemp -d)
trap 'rm -rf "$keep"' EXIT

run_mode() {
    local label=$1; shift
    local out rc
    out=$(bash "$DIR/verify.sh" --days "$DAYS" --keep "$keep/$label" "$@" 2>&1); rc=$?
    if grep -q 'negative control: a planted missing text' <<<"$out"; then
        pass "$label: verify.sh ran its own negative control first"
    else
        fail "$label: verify.sh did not report running its negative control — its grader is unproven" "$out"
    fi
    if (( rc == 0 )) && grep -q '^PASS: repl steps' <<<"$out"; then
        pass "$label: $(grep -m1 '^PASS:' <<<"$out" | cut -c1-120)"
    else
        fail "$label mode failed (rc=$rc)" "$(grep -E '^(FAIL|UNKNOWN):|✗' <<<"$out" | head -5)"
    fi
}
run_mode skeleton
run_mode solutions --solutions

summary
