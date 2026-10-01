#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/11_sedrepl_live.sh — drive a LIVE sedrepl tmux session with ttydrive.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have sed;   then echo "  SKIP: sed not installed";  exit 0; fi

trap repl_cleanup EXIT

# --- launch: substitution against #DATA ---
repl_start se "$REPO/sedrepl/sedrepl" .repl.sed <<'EOF'
s/foo/bar/g

#DATA
foo one
say foo
EOF

if repl_wait se 'bar one' 15; then
    pass "live output pane shows the substitution result"
else
    fail "live output never appeared" "$(repl_screen se)"
fi
assert_screen_contains se "# command:  sed" "runner pane shows the sed command header"

# --- edit -> reload ---
repl_edit se <<'EOF'
s/hello/HI/g

#DATA
hello there
EOF
if repl_wait se 'HI there' 15; then
    pass "editing the file live-reloads the sed output"
else
    fail "output did not update after edit" "$(repl_screen se)"
fi
assert_screen_not_contains se "bar one" "stale output is gone after reload"

# --- #ARGS -n with an explicit /p prints only matching lines ---
repl_edit se <<'EOF'
#ARGS -n
/^keep/p

#DATA
keep this
drop that
keep more
EOF
if repl_wait se 'keep more' 15; then
    pass "#ARGS -n with /p prints matching lines"
else
    fail "#ARGS -n path did not produce expected output" "$(repl_screen se)"
fi
assert_screen_not_contains se "drop that" "#ARGS -n suppresses non-matching lines"

# --- a file that is only data ('#DATA' on line 1): an empty sed script just
#     passes the rows through (the rows used to be run as the sed script too)
repl_edit se <<'EOF'
#DATA
only-data-row-one
only-data-row-two
EOF
if repl_wait se 'only-data-row-two' 15; then
    pass "#DATA on line 1: the rows pass through as data"
else
    fail "#DATA on line 1: the rows never appeared" "$(repl_screen se)"
fi
repl_settle se 800 >/dev/null
assert_screen_not_contains se "sed: " "#DATA on line 1: no sed error (the rows are not run as a script)"

summary
