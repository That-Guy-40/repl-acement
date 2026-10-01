#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  e2e/16_detach_reattach.sh — detaching from a REPL must leave it running.
##
##  For each REPL: launch it as a new tmux session, detach with C-b d, and
##  check the session and its temp files survive; reattach and check a save
##  still re-runs the tool; then quit (the editor exits) and check the
##  pane-exited hook removes the temp files and ends the session.
##
##  Regression test: the post-'tmux new' cleanup backstop used to run on a
##  plain detach too, deleting the files the live session still needed, which
##  made the formatter's entr exit and the kill-window hook end the session.
##

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$E2E_DIR/../.." && pwd)"
source "$REPO/tests/lib/helpers.sh"
source "$REPO/tests/lib/replpty.sh"

if ! repl_have_tmux; then echo "  SKIP: tmux not installed"; exit 0; fi
if ! repl_have entr;  then echo "  SKIP: entr not installed"; exit 0; fi

trap repl_cleanup EXIT

# wait_for SECS CMD... — poll CMD every 0.2s until it succeeds or SECS pass
wait_for() {
    local secs=$1 i; shift
    for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done
    return 1
}
no_session()  { ! repl_sessions | grep -qxF -- "$1"; }
no_scratch()  { [[ $(repl_scratch_count "$1") -eq 0 ]]; }

# content_for TOOL N — a program whose output is "M<N>-x", while its source
# never contains that literal string (the source pane shows the source too)
content_for() {
    local n=$2
    case $1 in
        awk)  printf '{ print "M%s-" $1 }\n\n#DATA\nx\n' "$n" ;;
        sed)  printf 's/x/M%s-&/\n\n#DATA\nx\n' "$n" ;;
        jq)   printf '"M%s-" + .\n\n#DATA\n"x"\n' "$n" ;;
        yq)   printf '"M%s-" + .a\n\n#DATA\na: x\n' "$n" ;;
        mlr)  printf '$m = "M%s-" . $a;\n\n#DATA\na,b\nx,y\n' "$n" ;;
        perl) printf 'print "M%s-$_"\n\n#DATA\nx\n' "$n" ;;
    esac
}

check_tool() {
    local tool=$1 repl=$2 base=$3 need=$4
    local name="d_$tool" again="r_$tool" sess pid

    if ! repl_have "$need"; then echo "  SKIP: $repl ($need not installed)"; return; fi
    if [[ $tool == yq ]] && ! yq --version 2>&1 | grep -qi mikefarah; then
        echo "  SKIP: $repl (yq on PATH is not Mike Farah's Go yq)"; return
    fi

    # redirect, don't pipe: a piped repl_start runs in a subshell, and its
    # record of the edited file (which repl_edit needs) would be lost
    repl_start "$name" "$REPO/$repl/$repl" "$base" < <(content_for "$tool" 1)
    if ! repl_wait "$name" 'M1-x' 15; then
        fail "$repl: initial output never appeared" "$(repl_screen "$name")"
        return
    fi
    repl_settle "$name" 800 >/dev/null

    # --- detach: the REPL's client returns, the session must live on ---
    repl_keys "$name" C-b d
    repl_wait_exit "$name" 10 >/dev/null
    sess=$(repl_sessions | grep -m1 "^$repl-")
    if [[ -n "$sess" ]]; then
        pass "$repl: session survives a detach ($sess)"
    else
        fail "$repl: session gone after detach" "sessions: $(repl_sessions | tr '\n' ' ')"
        return
    fi
    if [[ $(repl_scratch_count "$repl-") -gt 0 ]]; then
        pass "$repl: temp files survive a detach"
    else
        fail "$repl: temp files deleted on detach"
    fi

    # --- reattach: a save must still re-run the tool ---
    repl_attach "$again" "$sess"
    if ! repl_wait "$again" 'M1-x' 10; then
        fail "$repl: reattached screen does not show the output" "$(repl_screen "$again")"
        return
    fi
    repl_edit "$name" < <(content_for "$tool" 2)
    if repl_wait "$again" 'M2-x' 15; then
        pass "$repl: after reattaching, a save still re-runs the tool"
    else
        fail "$repl: no reload after reattach" "$(repl_screen "$again")"
    fi

    # --- quit (the editor exits): hooks clean up and end the session ---
    pid=$(repl_tmux display-message -p -t "=$sess:0.0" '#{pane_pid}')
    kill "$pid" 2>/dev/null
    if wait_for 10 no_session "$sess"; then
        pass "$repl: quitting the editor ends the session"
    else
        fail "$repl: session still alive after the editor exited"
    fi
    if wait_for 5 no_scratch "$repl-"; then
        pass "$repl: quitting removes the temp files"
    else
        fail "$repl: temp files left after quitting" "$(repl_scratch_count "$repl-") left"
    fi
}

check_tool awk  awkrepl  .repl.awk gawk
check_tool sed  sedrepl  .repl.sed sed
check_tool jq   jqrepl   .repl.jq  jq
check_tool yq   yqrepl   .repl.yq  yq
check_tool mlr  mlrrepl  .repl.mlr mlr
check_tool perl perlrepl .repl.pl  perl

summary
