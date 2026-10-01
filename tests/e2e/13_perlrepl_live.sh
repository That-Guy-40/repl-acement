#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/13_perlrepl_live.sh — drive a LIVE perlrepl tmux session with ttydrive.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have perl;  then echo "  SKIP: perl not installed"; exit 0; fi

trap repl_cleanup EXIT

# --- launch: a bare per-line expression gets -n added automatically ---
repl_start pl "$REPO/perlrepl/perlrepl" .repl.pl <<'EOF'
print uc

#DATA
hello world
EOF

if repl_wait pl 'HELLO WORLD' 15; then
    pass "bare per-line expression auto-gets -n and runs on #DATA"
else
    fail "live output never appeared" "$(repl_screen pl)"
fi
assert_screen_contains pl "# command:  perl" "runner pane shows the perl command header"
assert_screen_contains pl "perl -n"          "auto-added -n appears in the command header"

# --- edit -> reload with a substitution expression ---
repl_edit pl <<'EOF'
s/o/0/g; print;

#DATA
hello world
EOF
if repl_wait pl 'hell0 w0rld' 15; then
    pass "editing the file live-reloads the perl output"
else
    fail "output did not update after edit" "$(repl_screen pl)"
fi

# --- a full BEGIN block is a complete script: no -n is added ---
repl_edit pl <<'EOF'
BEGIN { print "boot: ", 6 * 7, "\n" }
EOF
if repl_wait pl 'boot:' 15; then
    pass "a BEGIN-block script runs without auto -n"
else
    fail "BEGIN-block script did not run" "$(repl_screen pl)"
fi

summary
