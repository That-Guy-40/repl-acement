#!/usr/bin/env bash
# =============================================================================
# replpty.sh — end-to-end driver for the tmux-based REPLs in this repo.
#
# Each *repl script launches a live three-pane tmux session and reacts to the
# edited file via entr. The per-project smoke/integration tests source the
# script and call its functions directly; they never launch the UI. This
# helper closes that gap: it starts a REPL in a REAL terminal (using the
# vendored ttydrive, tests/lib/ttydrive), lets you rewrite the edited file to
# trigger the entr reload, and reads back what the panes actually show.
#
# How it drives a REPL that itself spawns tmux:
#   - ttydrive runs on its OWN private tmux server (its own socket).
#   - We launch the REPL (in a 120x40 terminal) with TMUX cleared, so the
#     REPL starts its own `tmux new-session` that attaches to ttydrive's
#     visible pane. What ttydrive captures is the composited three-pane
#     screen a user sees.
#   - The REPL's inner tmux server is isolated under a per-run TMUX_TMPDIR
#     so cleanup can kill it precisely, touching nothing else on the box.
#     HOME (per session) and TMPDIR (the REPL's mktemp scratch) also point
#     into the per-run work area, which cleanup removes.
#   - The editor pane is replaced with a keep-alive no-op (REPLs read the
#     file, not the editor), and the file is rewritten from the test to
#     drive the entr event loop the same way a save would.
#
# IMPORTANT — reading the screen: the three panes are captured as one
# composited screen, so the two bottom panes share each text row (an output
# line reads as "alpha        <U+2502>{"). Assert with DISTINCTIVE SUBSTRINGS,
# not "^line$" anchors.
#
# Needs: bash 4+, tmux 3.0+ (same as ttydrive), and entr for the reloads.
# This file does not check for them itself: each e2e suite tests
# repl_have_tmux / repl_have entr (and its tool) and prints SKIP if missing.
#
# API
#   repl_have_tmux                       tmux present? (else skip the suite)
#   repl_have <cmd>                      command present?
#   repl_start NAME TOOL BASENAME        start REPL TOOL (abs path); BASENAME is
#                                        the edited file it opens in $HOME, a
#                                        per-session dir (e.g. .repl.awk).
#                                        Initial file content is read from stdin.
#   repl_edit NAME                       settle, then rewrite NAME's file from
#                                        stdin -> reload
#   repl_screen NAME                     print the visible composited screen
#   repl_transcript NAME                 screen + scrollback
#   repl_wait NAME REGEX [SECS]          wait until the transcript matches (10s)
#   repl_settle NAME [MS]                wait until the screen stops changing
#                                        for MS (500) ms, up to 10s
#   repl_replfile NAME                   path to NAME's edited file
#   repl_keys NAME KEY...                press keys in NAME's terminal (C-b d …)
#   repl_wait_exit NAME [SECS]           wait for NAME's program to exit (10s)
#   repl_tmux ARGS...                    tmux on the REPLs' own (inner) server
#   repl_sessions                        session names on the inner server
#   repl_scratch_count PREFIX            REPL temp files named PREFIX* in $TMPDIR
#   repl_attach NAME SESSION             new terminal NAME attached to SESSION
#   repl_sample TOOL N                   a small program (+ #DATA) for TOOL
#                                        (awk sed jq yq mlr perl) printing M<N>-x
#   repl_cleanup                         stop every session; kill inner servers
#
#   assert_screen_contains NAME TEXT MSG       checks screen + scrollback
#   assert_screen_not_contains NAME TEXT MSG   checks the visible screen only
#   assert_screen_matches NAME REGEX MSG       checks screen + scrollback
# =============================================================================

_RP_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
_RP_TOOL="$_RP_LIB/ttydrive"

# one isolated work area per test process
_RP_WORK="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/replpty.$$"
_RP_TD_DIR="$_RP_WORK/td"                # ttydrive's own state/server
_RP_INNER_TMPDIR="$_RP_WORK/inner"       # the REPLs' own tmux servers
_RP_REPL_TMPDIR="$_RP_WORK/tmp"          # the REPLs' mktemp scratch ($TMPDIR)
_RP_KEEPEDIT="$_RP_WORK/keepedit"        # no-op editor that stays alive

# NAME -> per-session home directory holding the edited file
declare -A _RP_HOME=()
# NAME -> basename of the edited file inside that home (e.g. .repl.awk)
declare -A _RP_BASENAME=()

repl_have_tmux() { command -v tmux >/dev/null 2>&1; }
repl_have()      { command -v "$1" >/dev/null 2>&1; }

# ttydrive on this run's private state directory
_rp() { TTYDRIVE_DIR="$_RP_TD_DIR" bash "$_RP_TOOL" "$@"; }

_rp_init() {
    [[ -e "$_RP_KEEPEDIT" ]] && return 0
    mkdir -p "$_RP_WORK" "$_RP_INNER_TMPDIR" "$_RP_REPL_TMPDIR" || return 1
    # an $EDITOR that ignores its file argument and never exits, so the REPL's
    # editor pane stays open (its exit would fire the cleanup/kill-window hook)
    printf '#!/usr/bin/env bash\nexec sleep 2147483647\n' > "$_RP_KEEPEDIT"
    chmod +x "$_RP_KEEPEDIT"
}

repl_replfile() { printf '%s/%s' "${_RP_HOME[$1]}" "${_RP_BASENAME[$1]}"; }

# repl_start NAME TOOL BASENAME  (< initial content)
repl_start() {
    local name=$1 tool=$2 base=$3
    _rp_init || return 1
    local home="$_RP_WORK/home.$name"
    mkdir -p "$home"
    _RP_HOME[$name]="$home"
    _RP_BASENAME[$name]="$base"
    cat > "$home/$base"                          # initial edited-file content
    _rp start "$name" -s 120x40 \
        -e HOME="$home" \
        -e EDITOR="$_RP_KEEPEDIT" \
        -e TMUX= \
        -e TMUX_TMPDIR="$_RP_INNER_TMPDIR" \
        -e TMPDIR="$_RP_REPL_TMPDIR" \
        -e PATH="$PATH" \
        -- "$tool"
}

# repl_edit NAME  (< new content)  — rewrite the file in place -> entr reload.
#
# Settle first: entr runs its utility once at startup and only then arms its
# watch, so an edit landing in that window is silently lost (the first edit
# after launch, most often). Waiting for the screen to go quiet lets entr arm,
# and also keeps back-to-back edits from coalescing into one reload.
repl_edit() {
    local f; f="$(repl_replfile "$1")"
    _rp settle "$1" -q 500 -t 8 >/dev/null 2>&1 || true
    cat > "$f"
}

repl_screen()     { _rp screen "$1"; }
repl_transcript() { _rp screen "$1" --all; }
repl_wait()       { _rp wait "$1" "$2" -t "${3:-10}"; }
repl_settle()     { _rp settle "$1" -q "${2:-500}" -t 10; }
repl_keys()       { _rp keys "$@"; }
repl_wait_exit()  { _rp wait-exit "$1" -t "${2:-10}"; }

# repl_sample TOOL N — a program whose output is "M<N>-x", while its source
# never contains that literal string (the source pane shows the source too)
repl_sample() {
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

# --- the REPLs' own (inner) tmux server and scratch files --------------------

# tmux on the REPLs' inner server (the one isolated under our TMUX_TMPDIR)
repl_tmux() { tmux -S "$_RP_INNER_TMPDIR/tmux-$(id -u)/default" "$@"; }

# repl_sessions — names of the sessions on the inner server, one per line
repl_sessions() { repl_tmux list-sessions -F '#{session_name}' 2>/dev/null; }

# repl_scratch_count PREFIX — how many of the REPLs' temp files start with
# PREFIX (e.g. "awkrepl-") in the isolated $TMPDIR
repl_scratch_count() {
    find "$_RP_REPL_TMPDIR" -maxdepth 1 -name "$1*" 2>/dev/null | wc -l
}

# repl_attach NAME SESSION — open a new terminal NAME attached to the inner
# server's SESSION (to reattach after the REPL's client has detached)
repl_attach() {
    _rp start "$1" -s 120x40 -e TMUX= -e PATH="$PATH" -- \
        tmux -S "$_RP_INNER_TMPDIR/tmux-$(id -u)/default" attach -t "=$2"
}

repl_cleanup() {
    _rp stop --all 2>/dev/null
    # kill each REPL's own (inner) tmux server, isolated under our TMPDIR
    local sock
    while IFS= read -r sock; do
        [[ -n "$sock" ]] && tmux -S "$sock" kill-server 2>/dev/null
    done < <(find "$_RP_INNER_TMPDIR" -name '*' -type s 2>/dev/null)
    rm -rf "$_RP_WORK" 2>/dev/null
    _RP_HOME=(); _RP_BASENAME=()
    return 0
}

# --- assertions (thin wrappers over helpers.sh's assert_*) --------------------

assert_screen_contains() {
    assert_output_contains "$3" "$2" repl_transcript "$1"
}
assert_screen_not_contains() {
    # visible screen only: entr's clear (-c) may leave stale output in the
    # scrollback, so "no longer showing X" is a statement about what is visible
    local name=$1 needle=$2 desc=$3 actual
    actual=$(repl_screen "$name" 2>&1)
    if echo "$actual" | grep -qF -- "$needle"; then
        fail "$desc" "screen unexpectedly contains: $needle"
    else
        pass "$desc"
    fi
}
assert_screen_matches() {
    local name=$1 regex=$2 desc=$3 actual
    actual=$(repl_transcript "$name" 2>&1)
    if echo "$actual" | grep -qE -- "$regex"; then
        pass "$desc"
    else
        fail "$desc" "screen does not match: $regex"
    fi
}
