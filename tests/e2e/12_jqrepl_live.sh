#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/12_jqrepl_live.sh — drive a LIVE jqrepl tmux session with ttydrive.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have jq;    then echo "  SKIP: jq not installed";   exit 0; fi

trap repl_cleanup EXIT

# --- launch: filter against #DATA ---
repl_start jq "$REPO/jqrepl/jqrepl" .repl.jq <<'EOF'
.name

#DATA
{"name": "Ada", "role": "pioneer"}
EOF

if repl_wait jq 'Ada' 15; then
    pass "live output pane shows the jq filter result"
else
    fail "live output never appeared" "$(repl_screen jq)"
fi
assert_screen_contains jq "# command:  jq" "runner pane shows the jq command header"

# --- edit -> reload ---
repl_edit jq <<'EOF'
.role

#DATA
{"name": "Ada", "role": "pioneer"}
EOF
if repl_wait jq 'pioneer' 15; then
    pass "editing the file live-reloads the jq output"
else
    fail "output did not update after edit" "$(repl_screen jq)"
fi
assert_screen_not_contains jq "Ada" "stale output is gone after reload"

# --- no #DATA: jq runs with -n (null input) so it does not block on stdin ---
repl_edit jq <<'EOF'
"sum=\(6 * 7)"
EOF
if repl_wait jq 'sum=42' 15; then
    pass "no-#DATA expression runs with jq -n (null input) and evaluates"
else
    fail "null-input expression did not evaluate" "$(repl_screen jq)"
fi
assert_screen_contains jq "jq -n" "command header shows the -n (null input) form"

summary
