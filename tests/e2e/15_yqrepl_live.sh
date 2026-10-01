#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/15_yqrepl_live.sh — drive a LIVE yqrepl tmux session with ttydrive.
##
##  yqrepl targets Mike Farah's Go yq (github.com/mikefarah/yq), whose grammar
##  ('yq eval', --null-input) differs from the unrelated Python "yq". If the
##  yq on PATH is not Mike Farah's, this suite skips rather than misreport.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have yq;    then echo "  SKIP: yq not installed";   exit 0; fi
if ! yq --version 2>&1 | grep -qi 'mikefarah'; then
    echo "  SKIP: yq on PATH is not Mike Farah's Go yq (yqrepl targets that one)"
    exit 0
fi

trap repl_cleanup EXIT

# --- launch: field extraction against YAML #DATA ---
repl_start yq "$REPO/yqrepl/yqrepl" .repl.yq <<'EOF'
.name

#DATA
name: Ada
role: pioneer
EOF

if repl_wait yq 'Ada' 15; then
    pass "live output pane shows the yq filter result"
else
    fail "live output never appeared" "$(repl_screen yq)"
fi
assert_screen_contains yq "# command:  yq" "runner pane shows the yq command header"

# --- edit -> reload ---
repl_edit yq <<'EOF'
.role

#DATA
name: Ada
role: pioneer
EOF
if repl_wait yq 'pioneer' 15; then
    pass "editing the file live-reloads the yq output"
else
    fail "output did not update after edit" "$(repl_screen yq)"
fi
assert_screen_not_contains yq "Ada" "stale output is gone after reload"

# --- no #DATA: --null-input lets a pure expression produce output ---
repl_edit yq <<'EOF'
"sum=" + (6 * 7 | tostring)
EOF
if repl_wait yq 'sum=42' 15; then
    pass "no-#DATA expression runs with --null-input"
else
    fail "null-input expression did not evaluate" "$(repl_screen yq)"
fi
assert_screen_contains yq "null-input" "command header shows the --null-input form"

summary
