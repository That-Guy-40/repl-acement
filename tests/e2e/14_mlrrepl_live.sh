#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/14_mlrrepl_live.sh — drive a LIVE mlrrepl tmux session with ttydrive.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi
if ! repl_have mlr;   then echo "  SKIP: mlr (miller) not installed"; exit 0; fi

trap repl_cleanup EXIT

# --- launch: DSL against CSV #DATA (format auto-detected as --csv) ---
repl_start ml "$REPO/mlrrepl/mlrrepl" .repl.mlr <<'EOF'
$total = $qty * $price;

#DATA
qty,price
3,4
EOF

if repl_wait ml "3,4,12" 15; then
    pass "live output shows the computed field (CSV auto-detected)"
else
    fail "live output never appeared" "$(repl_screen ml)"
fi
assert_screen_contains ml "# command:  mlr" "runner pane shows the mlr command header"
assert_screen_contains ml "--csv"           "CSV format was auto-detected in the command header"

# --- edit -> reload ---
repl_edit ml <<'EOF'
$sum = $a + $b;

#DATA
a,b
10,20
EOF
if repl_wait ml "10,20,30" 15; then
    pass "editing the file live-reloads the mlr output"
else
    fail "output did not update after edit" "$(repl_screen ml)"
fi

# --- no #DATA: mlrrepl prints its guidance hint instead of hanging ---
repl_edit ml <<'EOF'
$x = 1;
EOF
if repl_wait ml 'no #DATA' 15; then
    pass "no-#DATA case prints the guidance hint (does not block)"
else
    fail "missing-data hint did not appear" "$(repl_screen ml)"
fi

summary
