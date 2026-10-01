#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/17_nested_tmux.sh — a REPL started inside an existing tmux session
##  must only ever affect its own window.
##
##  A host tmux session (standing in for the user's own) gets a window of its
##  own, then each REPL is launched from a pane inside it, so the REPL opens
##  as a new window (the nested case). Then:
##    - other panes in the session exit (the launcher pane, and an unrelated
##      window): the REPL window, its temp files and the user's window must
##      all survive, and a save must still re-run the tool;
##    - no pane-exited hooks may be left on the user's session;
##    - quitting the REPL's editor closes only the REPL's window and removes
##      its temp files; so does killing the REPL window from tmux, or one of
##      its entr panes exiting.
##
##  Regression test: the REPLs used to install session-wide 'pane-exited'
##  hooks (cleanup + kill-window). tmux resolves those against the session's
##  current window, so any pane exiting anywhere in the user's session wiped
##  the REPL's files and killed a window.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"      # for repl_sample

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi

W=$(mktemp -d "${TMPDIR:-/tmp}/nested.XXXXXX")
SOCK="$W/tmux.sock"
H() { tmux -S "$SOCK" "$@"; }            # the host (user's) tmux server
trap 'H kill-server 2>/dev/null; rm -rf "$W"' EXIT

printf '#!/usr/bin/env bash\nexec sleep 2147483647\n' > "$W/keepedit"
chmod +x "$W/keepedit"
H new-session -d -s host -n mine -x 120 -y 40 'sleep 2147483647'

# wait_for SECS CMD... — poll CMD every 0.2s until it succeeds or SECS pass
wait_for() {
    local secs=$1 i; shift
    for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done
    return 1
}
has_window()  { H list-windows -t host -F '#{window_name}' 2>/dev/null | grep -qxF -- "$1"; }
no_window()   { ! has_window "$1"; }
pane_shows()  { H capture-pane -p -t "host:$1" 2>/dev/null | grep -qF -- "$2"; }
scratch()     { find "$W/tmp.$1" -maxdepth 1 -name "$1-*" 2>/dev/null | wc -l; }
no_scratch()  { [[ $(scratch "$1") -eq 0 ]]; }

# launch_nested TOOL REPL BASE — start REPL from a pane inside the host session
# ($TMUX is set there), so it opens as a new window; that launcher pane then
# exits by itself. Succeeds once the REPL's output pane shows M1-x.
launch_nested() {
    local tool=$1 repl=$2 base=$3 home="$W/home.$1"
    mkdir -p "$home" "$W/tmp.$repl"
    repl_sample "$tool" 1 > "$home/$base"
    H new-window -d -n "launch-$tool" \
        "env HOME=$(printf '%q' "$home") EDITOR=$(printf '%q' "$W/keepedit") TMPDIR=$(printf '%q' "$W/tmp.$repl") PATH=$(printf '%q' "$PATH") $(printf '%q' "$REPO/$repl/$repl")"
    wait_for 15 pane_shows "$repl.1" 'M1-x' || return 1
    wait_for 5 no_window "launch-$tool"          # the launcher pane has exited
}

check_tool() {
    local tool=$1 repl=$2 base=$3 need=$4 home="$W/home.$1" pid

    if ! repl_have "$need"; then echo "  SKIP: $repl ($need not installed)"; return; fi
    if [[ $tool == yq ]] && ! yq --version 2>&1 | grep -qi mikefarah; then
        echo "  SKIP: $repl (yq on PATH is not Mike Farah's Go yq)"; return
    fi

    if ! launch_nested "$tool" "$repl" "$base"; then
        fail "$repl: nested REPL window never showed output" \
             "windows: $(H list-windows -t host -F '#{window_name}' | tr '\n' ' ')"
        return
    fi

    # another, unrelated pane in the user's session exits
    H new-window -d -n "other-$tool" 'sleep 0.2'
    wait_for 5 no_window "other-$tool"
    sleep 1                                       # let any (wrong) hook run

    if has_window "$repl"; then
        pass "$repl: REPL window survives other panes exiting in the session"
    else
        fail "$repl: REPL window was killed when an unrelated pane exited"
        return
    fi
    if [[ $(scratch "$repl") -gt 0 ]]; then
        pass "$repl: temp files survive other panes exiting"
    else
        fail "$repl: temp files were deleted when an unrelated pane exited"
    fi
    if has_window mine; then
        pass "$repl: the user's own window is untouched"
    else
        fail "$repl: the user's own window was killed"
    fi
    if [[ $(H show-hooks -t host 2>/dev/null | grep -c pane-exited) -eq 0 &&
          $(H show-hooks -g 2>/dev/null | grep -c 'pane-exited\[') -eq 0 ]]; then
        pass "$repl: no pane-exited hooks left on the user's session"
    else
        fail "$repl: pane-exited hooks were installed on the session" "$(H show-hooks -t host)"
    fi

    # the REPL still works: a save re-runs the tool
    repl_sample "$tool" 2 > "$home/$base"
    if wait_for 15 pane_shows "$repl.1" 'M2-x'; then
        pass "$repl: a save still re-runs the tool"
    else
        fail "$repl: no reload after other panes exited"
    fi

    # quit the REPL's editor: only its own window closes, files are removed
    pid=$(H display-message -p -t "host:$repl.0" '#{pane_pid}')
    pkill -TERM -P "$pid" 2>/dev/null
    if wait_for 10 no_window "$repl"; then
        pass "$repl: quitting the editor closes the REPL window"
    else
        fail "$repl: REPL window still open after the editor exited"
    fi
    if wait_for 5 no_scratch "$repl"; then
        pass "$repl: quitting removes the temp files"
    else
        fail "$repl: temp files left after quitting" "$(scratch "$repl") left"
    fi
    if has_window mine; then
        pass "$repl: quitting leaves the user's own window open"
    else
        fail "$repl: quitting killed the user's own window"
    fi

    # --- the REPL window is killed from tmux (e.g. C-b &): the editor pane's
    #     wrapper gets SIGHUP and still removes the temp files ---
    if launch_nested "$tool" "$repl" "$base"; then
        H kill-window -t "host:$repl"
        if wait_for 5 no_scratch "$repl"; then
            pass "$repl: killing the REPL window removes the temp files"
        else
            fail "$repl: temp files left after the window was killed" "$(scratch "$repl") left"
        fi
        has_window mine && pass "$repl: killing the REPL window leaves the user's window" \
                        || fail "$repl: killing the REPL window killed the user's window"
    else
        fail "$repl: relaunch for the kill-window check failed"
    fi

    # --- the runner pane's entr exits: the REPL window closes and is cleaned up ---
    if launch_nested "$tool" "$repl" "$base"; then
        pid=$(H display-message -p -t "host:$repl.1" '#{pane_pid}')
        pkill -TERM -P "$pid" 2>/dev/null                 # entr, under the pane's shell
        if wait_for 10 no_window "$repl"; then
            pass "$repl: an entr pane exiting closes the REPL window"
        else
            fail "$repl: REPL window still open after its entr exited"
        fi
        if wait_for 5 no_scratch "$repl"; then
            pass "$repl: …and removes the temp files"
        else
            fail "$repl: temp files left after entr exited" "$(scratch "$repl") left"
        fi
        has_window mine && pass "$repl: …and leaves the user's window" \
                        || fail "$repl: an entr pane exiting killed the user's window"
    else
        fail "$repl: relaunch for the entr-exit check failed"
    fi
}

check_tool awk  awkrepl  .repl.awk gawk
check_tool sed  sedrepl  .repl.sed sed
check_tool jq   jqrepl   .repl.jq  jq
check_tool yq   yqrepl   .repl.yq  yq
check_tool mlr  mlrrepl  .repl.mlr mlr
check_tool perl perlrepl .repl.pl  perl

summary
