#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/10_awkrepl_live.sh — drive a LIVE awkrepl tmux session with ttydrive.
##
##  Unlike the per-project smoke/integration tests (which source awkrepl and
##  call its functions directly), this launches the real three-pane UI, reads
##  what the panes show, then rewrites the edited file and checks that the
##  entr event loop re-runs and updates the output — the actual user workflow.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have gawk;  then echo "  SKIP: gawk not installed"; exit 0; fi

trap repl_cleanup EXIT

# --- launch: initial program + #DATA shows output and pretty-printed source ---
repl_start aw "$REPO/awkrepl/awkrepl" .repl.awk <<'EOF'
{ print $2 }

#DATA
hello world
foo bar
EOF

if repl_wait aw 'world' 15; then
    pass "live output pane shows result of '{ print \$2 }' on #DATA"
else
    fail "live output never appeared" "$(repl_screen aw)"
fi
assert_screen_contains aw "# command:  gawk" "runner pane shows the gawk command header"
# the formatter pane has its own ~1s delay; wait for it before asserting
if repl_wait aw 'print' 15; then
    assert_screen_contains aw "print \$2" "formatter pane shows the pretty-printed source"
else
    fail "formatter pane never rendered the source" "$(repl_screen aw)"
fi

# --- edit the file -> entr reloads -> output changes ---
repl_edit aw <<'EOF'
{ print toupper($1) }

#DATA
hello world
foo bar
EOF

if repl_wait aw 'HELLO' 15; then
    pass "editing the file live-reloads the output (entr event loop works)"
else
    fail "output did not update after edit" "$(repl_screen aw)"
fi
assert_screen_not_contains aw "world" "stale output ('world') is gone after reload"

# --- no #DATA: bare expression is END{}-wrapped and runs once ---
repl_edit aw <<'EOF'
print "ans=" 6 * 7
EOF
if repl_wait aw 'ans=42' 15; then
    pass "no-#DATA bare expression is END{}-wrapped and evaluates (42)"
else
    fail "END{}-wrapped expression did not evaluate" "$(repl_screen aw)"
fi

# --- a syntax error surfaces in the formatter pane, not a crash ---
repl_edit aw <<'EOF'
{ print $1
EOF
if repl_wait aw 'ERROR' 15; then
    pass "invalid AWK surfaces an ERROR in the formatter pane"
else
    fail "syntax error was not reported on screen" "$(repl_screen aw)"
fi

summary
