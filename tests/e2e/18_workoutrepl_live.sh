#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/18_workoutrepl_live.sh — drive a LIVE workoutrepl tmux session with ttydrive.
##
##  workoutrepl's save does more than re-run a tool: it writes the edited body
##  into a graded fixture under $HOME/workout, runs it, and a second entr pane
##  re-grades the day. This launches the real three-pane UI and checks each of
##  those effects from outside — the files in the fixture and the text of the
##  panes — then switches days, saves a header-less file, and quits.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi

trap repl_cleanup EXIT

wait_for() {
    local secs=$1 i; shift
    for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done
    return 1
}
no_session() { ! repl_sessions | grep -qxF -- "$1"; }
no_scratch() { [[ $(repl_scratch_count "$1") -eq 0 ]]; }

# --- launch: the REPL's own first file (#DAY 1, no #FILE) ---
repl_start wr "$REPO/workoutrepl/workoutrepl" .repl.workout <<'EOF'
# narration — never written anywhere
#DAY 1
EOF
HOME_D=$(dirname "$(repl_replfile wr)")

if repl_wait wr 'no #FILE header: nothing written' 20; then
    pass "output pane: the first run says nothing was written (no #FILE)"
else
    fail "the output pane never ran the first file" "$(repl_screen wr)"
fi
if repl_wait wr 'FAIL: day 01' 30; then
    pass "check pane: day 1 graded after the first run"
else
    fail "the check pane never graded day 1" "$(repl_screen wr)"
fi
if [[ $(repl_scratch_count workoutrepl-) -ge 8 ]]; then
    pass "the REPL's scratch files are under TMPDIR"
else
    fail "expected 8 workoutrepl-* scratch files under TMPDIR" "$(repl_scratch_count workoutrepl-) found"
fi

# --- save 1: a day-7 piece — fixture built on demand, file written, #RUN run, day 7 graded ---
repl_edit wr <<'EOF'
#DAY 7
#FILE tidy.sh
#RUN ./tidy.sh downloads
#!/usr/bin/env bash
echo "tidy.sh placeholder for $1"
exit 3
EOF
if repl_wait wr 'wrote:   day07/tidy.sh' 30; then
    pass "save: output pane reports writing day07/tidy.sh"
else
    fail "the save was not written" "$(repl_screen wr)"
fi
assert_screen_contains wr "exit:    3" "output pane shows the piece's exit status"
if [[ -x "$HOME_D/workout/day07/tidy.sh" ]]; then
    pass "day07/tidy.sh exists in the fixture, executable (body starts with #!)"
else
    fail "day07/tidy.sh missing or not executable" "$(ls -la "$HOME_D/workout/day07" 2>&1)"
fi
if [[ -d "$HOME_D/workout/day07/downloads" ]]; then
    pass "the day-7 fixture was built on demand"
else
    fail "no day-7 fixture under \$HOME/workout" "$(ls "$HOME_D/workout" 2>&1)"
fi
if repl_wait wr 'FAIL: day 07' 40; then
    pass "check pane: day 7 re-graded after the save"
else
    fail "the check pane did not re-grade day 7" "$(repl_screen wr)"
fi
assert_screen_contains wr "tidy.log is missing" "check pane names the defect"

# --- save 2: switch days; the LAST grade must be the new day (regression: stale re-stamp) ---
repl_edit wr <<'EOF'
#DAY 5
#FILE pe.sh
#!/usr/bin/env bash
echo placeholder
EOF
if repl_wait wr 'wrote:   day05/pe.sh' 30; then
    pass "save 2: day05/pe.sh written"
else
    fail "the second save was not written" "$(repl_screen wr)"
fi
if repl_wait wr 'FAIL: day 05' 40; then
    pass "check pane: day 5 graded after the day changed"
else
    fail "the check pane did not grade day 5" "$(repl_screen wr)"
fi
sleep 3        # any stale re-stamp of day 7 would land by now
last=$(repl_screen wr | grep -oE '(PASS|FAIL): day 0[0-9]' | tail -1)
assert_equals "the last verdict on screen is day 05 (nothing re-graded day 7 afterwards)" "FAIL: day 05" "$last"

# --- save 3: no #DAY → the hint ---
repl_edit wr <<'EOF'
# just a comment, no headers
EOF
if repl_wait wr 'add a header line' 30; then
    pass "a file with no #DAY gets the usage hint"
else
    fail "no hint for a header-less file" "$(repl_screen wr)"
fi

# --- quit: ending the editor runs the wrapper's cleanup and ends the session ---
sess=$(repl_sessions | grep -m1 '^workoutrepl-')
if [[ -n "$sess" ]]; then
    pass "the REPL opened its own session ($sess)"
else
    fail "no workoutrepl-* session on the inner server" "$(repl_sessions)"
fi
pane_pid=$(repl_tmux display-message -p -t "=$sess:0.0" '#{pane_pid}')
# the pane runs the editor wrapper; its child is the keep-alive editor. Resolve the
# PIDs and kill those, never a pattern.
for child in $(pgrep -P "$pane_pid"); do kill -TERM "$child" 2>/dev/null; done
if wait_for 10 no_session "$sess"; then
    pass "quitting the editor ends the session"
else
    fail "session still alive after the editor exited"
fi
if wait_for 5 no_scratch workoutrepl-; then
    pass "quitting removes the temp files"
else
    fail "temp files left after quitting" "$(repl_scratch_count workoutrepl-) left"
fi

summary
