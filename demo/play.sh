#!/usr/bin/env bash
##
##  demo/play.sh — self-running (or step-by-step) playback of a step directory.
##
##  Opens a tmux session, starts each REPL from a shell inside it (so the
##  audience sees `$ awkrepl` typed, and the REPL opens as a window), then
##  types every step of the directory's NN_*.repl files into the real
##  editor (vim) and saves, which is what makes the output pane re-run.
##  Narration lives in the step files as comments, so it shows in the editor.
##
##  Usage:
##    demo/play.sh                      play demo/steps, attached, on a timer
##    demo/play.sh --dir DIR            play another step directory (a tutorial)
##    demo/play.sh --interactive        step by step: F5 advances, and between
##                                      steps the editor is yours to experiment in
##    demo/play.sh --steps 1,4,9        only those step numbers
##    demo/play.sh --fast --no-attach --capture DIR
##                                      headless, no pauses: what verify.sh runs
##    demo/play.sh --no-preamble        don't type the one-line pane guide above each step
##
##  Step file format (NN_*.repl):
##    #> tool: awkrepl          which REPL (window name == command name)
##    #> needs: real            needs demo/data/real/creditcard.csv (@REAL@)
##    #> needs: yq-mikefarah    needs Mike Farah's Go yq on PATH
##    #> wait: TEXT             typed+saved, then wait for TEXT in the output pane
##    #> pause: SECS            narration time before the next step (timer mode)
##    #> must: / #> not: / #> source:   assertions, used by verify.sh only
##    everything else is typed into the editor verbatim; the first line is
##    the step's title; a @CSV@ line is replaced by demo/data/transactions.csv
##    and the #DATA block is pasted rather than typed.
##
set -uo pipefail

DEMO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd "$DEMO_DIR/.." && pwd -P)
CSV="$DEMO_DIR/data/transactions.csv"
REAL="$DEMO_DIR/data/real/creditcard.csv"

STEPS_DIR="$DEMO_DIR/steps"
FAST=0 ATTACH=1 INTERACTIVE=0 PREAMBLE=1 CAPTURE='' SOCK="demo-$$" ONLY='' SIZE=200x50
TYPE_DELAY=${DEMO_TYPE_DELAY:-0.02}      # seconds per typed character
PAUSE_SCALE=${DEMO_PAUSE_SCALE:-1}       # multiplier on each step's pause
NEXT_KEY=${DEMO_NEXT_KEY:-F5}            # interactive mode: key that advances

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^##\{0,1\} \{0,1\}//' | sed '$d'; }

while (( $# )); do
    case $1 in
        --dir)         STEPS_DIR=$(cd "$2" && pwd -P) || exit 2; shift ;;
        --fast)        FAST=1; TYPE_DELAY=0; PAUSE_SCALE=0 ;;
        --no-attach)   ATTACH=0 ;;
        --interactive) INTERACTIVE=1 ;;
        --no-preamble) PREAMBLE=0 ;;
        --capture)     CAPTURE=$2; shift ;;
        --socket)      SOCK=$2; shift ;;
        --steps)       ONLY=$2; shift ;;
        --size)        SIZE=$2; shift ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "play.sh: unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
(( INTERACTIVE && ! ATTACH )) && { echo "play.sh: --interactive needs an attached terminal" >&2; exit 2; }

for need in tmux entr vim; do
    command -v "$need" >/dev/null 2>&1 || { echo "play.sh: $need is required" >&2; exit 1; }
done
[[ -d "$STEPS_DIR" ]] || { echo "play.sh: no such step directory: $STEPS_DIR" >&2; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/repl-demo.XXXXXX") || exit 1
HOME_D="$WORK/home"; TMP_D="$WORK/tmp"; mkdir -p "$HOME_D" "$TMP_D"
LOG="$WORK/driver.log"
NEXT_FLAG="$WORK/next"
[[ -n "$CAPTURE" ]] && mkdir -p "$CAPTURE"

# the REPLs and (if fetched) demo/bin/yq go first on the demo shell's PATH
PATH_D="$REPO/awkrepl:$REPO/sedrepl:$REPO/jqrepl:$REPO/yqrepl:$REPO/mlrrepl:$REPO/perlrepl:$DEMO_DIR/bin:$PATH"

T() { tmux -L "$SOCK" "$@"; }
cleanup() { T kill-server 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

log() {
    if (( ATTACH )); then printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >> "$LOG"
    else                  printf '[demo] %s\n' "$*" >&2; fi
}
status_line() { T set -g status-right " $* " >/dev/null; }

# wait_for SECS CMD... — poll CMD every 0.2s until it succeeds or SECS pass
wait_for() {
    local secs=$1 i; shift
    for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done
    return 1
}
window_open()   { [[ $(T list-panes -t "demo:$1" -F x 2>/dev/null | wc -l) -eq 3 ]]; }
window_gone()   { ! T list-windows -t demo -F '#{window_name}' 2>/dev/null | grep -qxF -- "$1"; }
pane_text()     { T capture-pane -p -t "demo:$1" 2>/dev/null; }
pane_has()      { pane_text "$1" | grep -qF -- "$2"; }
# pane_shows_new PANE TEXT BEFORE — TEXT is there and the pane is not still
# showing the pre-save screen (which matters when TEXT was already on it)
pane_shows_new(){ local now; now=$(pane_text "$1"); grep -qF -- "$2" <<<"$now" && [[ "$now" != "$3" ]]; }
client_present(){ [[ -n $(T list-clients 2>/dev/null) ]]; }
has_mf_yq()     { yq --version 2>&1 | grep -qi mikefarah; }
next_pressed()  { [[ -e "$NEXT_FLAG" ]]; }

# type_text TARGET TEXT — type TEXT key by key (newline = Enter). A lone ';'
# would end the tmux command, so it is sent as '\;'.
type_text() {
    local tgt=$1 text=$2 i c
    for ((i = 0; i < ${#text}; i++)); do
        c=${text:i:1}
        case $c in
            $'\n') T send-keys -t "$tgt" Enter ;;
            ';')   T send-keys -t "$tgt" -l '\;' ;;
            *)     T send-keys -t "$tgt" -l "$c" ;;
        esac
        [[ $TYPE_DELAY != 0 ]] && sleep "$TYPE_DELAY"
    done
}
# paste_text TARGET TEXT — put TEXT in at once (vim is in insert mode, 'paste' set)
paste_text() {
    printf '%s' "$2" | T load-buffer -b demo -
    T paste-buffer -b demo -t "$1" -d
}

CUR=            # window name of the REPL currently open, if any
STEP_I=0 STEP_N=0

open_tool() {
    local tool=$1
    [[ -n "$CUR" ]] && quit_tool
    log "launching $tool"
    type_text demo:shell "$tool"
    T send-keys -t demo:shell Enter
    wait_for 20 window_open "$tool" || { log "FAIL: $tool window did not open"; return 1; }
    # label the pane borders, so the layout explains itself between steps
    T select-pane -t "demo:$tool.0" -T "EDITOR: edit here, save (:w) to run"
    T select-pane -t "demo:$tool.1" -T "OUTPUT: re-runs on every save"
    T select-pane -t "demo:$tool.2" -T "SOURCE: $(source_label "$tool")"
    sleep 1.5                       # vim up, entr armed
    CUR=$tool
}

# source_label TOOL — what the bottom-right pane shows for TOOL
source_label() { [[ $1 == awkrepl ]] && echo "the program as gawk parsed it" || echo "the program, highlighted"; }

# preamble TOOL — the one-line pane guide typed above every step (a comment,
# so every tool ignores it; awkrepl and yqrepl strip it, the others echo it)
preamble() {
    local right; right=$(source_label "$1")
    local line="# Panes: edit here, save to run | below left: output | below right: $right"
    (( INTERACTIVE )) && line+=" | $NEXT_KEY: next step"
    printf '%s' "$line"
}

quit_tool() {
    log "quitting $CUR"
    T send-keys -t "demo:$CUR.0" Escape ':q!' Enter
    wait_for 10 window_gone "$CUR" || log "warning: $CUR window still open"
    CUR=
    sleep 0.5
}

# run_step FILE — parse, open the tool if needed, type, save, wait, capture, pause
run_step() {
    local file=$1 num base tool wait pause=30 needs=() line body=() key val title=''
    base=$(basename "$file" .repl); num=${base%%_*}
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == '#> '* ]]; then
            key=${line#\#> }; val=${key#*: }; key=${key%%:*}
            case $key in
                tool)  tool=$val ;;
                wait)  wait=$val ;;
                pause) pause=$val ;;
                needs) needs+=("$val") ;;
            esac
        elif [[ $line == '@CSV@' ]]; then
            body+=("$(cat "$CSV")")
        else
            [[ -z $title ]] && title=${line#\# }
            body+=("$line")
        fi
    done < "$file"
    STEP_I=$((STEP_I + 1))

    local status="$CAPTURE/$num.status"
    for val in "${needs[@]+"${needs[@]}"}"; do
        case $val in
            real)         [[ -f "$REAL" ]] || { log "SKIP $base: $REAL not fetched (demo/fetch-deps.sh)"; [[ -n $CAPTURE ]] && echo "skipped: real dataset not fetched" > "$status"; return 0; } ;;
            yq-mikefarah) PATH="$PATH_D" has_mf_yq  || { log "SKIP $base: yq on PATH is not Mike Farah's Go yq (demo/fetch-deps.sh)"; [[ -n $CAPTURE ]] && echo "skipped: Mike Farah yq not on PATH" > "$status"; return 0; } ;;
        esac
    done

    [[ "$CUR" == "$tool" ]] || open_tool "$tool" || { [[ -n $CAPTURE ]] && echo "failed: $tool did not open" > "$status"; return 1; }
    if (( INTERACTIVE )); then
        status_line "step $STEP_I/$STEP_N  |  typing…"
        rm -f "$NEXT_FLAG"      # a press from before this step doesn't count; one during it does
    fi

    # split: everything up to #DATA is typed, #DATA and after is pasted
    local typed='' pasted='' in_data=0
    for line in "${body[@]}"; do
        line=${line//@REAL@/$REAL}
        if (( ! in_data )) && [[ $line == '#DATA' ]]; then in_data=1; fi
        if (( in_data )); then pasted+="$line"$'\n'; else typed+="$line"$'\n'; fi
    done
    # vim adds the final newline itself; a trailing one here would leave an
    # empty last line, which Miller reads as a one-field data row
    pasted=${pasted%$'\n'}
    [[ -z "$pasted" ]] && typed=${typed%$'\n'}
    (( PREAMBLE )) && typed="$(preamble "$tool")"$'\n'"$typed"

    local ed="demo:$tool.0" before
    before=$(pane_text "$tool.1")
    log "step $num: typing"
    T send-keys -t "$ed" Escape
    T send-keys -t "$ed" -l 'ggdG'
    T send-keys -t "$ed" -l 'i'
    if (( FAST )); then paste_text "$ed" "$typed"; else type_text "$ed" "$typed"; fi
    [[ -n "$pasted" ]] && paste_text "$ed" "$pasted"
    T send-keys -t "$ed" Escape
    T send-keys -t "$ed" -l ':w'
    T send-keys -t "$ed" Enter
    T send-keys -t "$ed" -l 'gg'   # back to the narration and program at the top

    local ok=1
    if ! wait_for 20 pane_shows_new "$tool.1" "$wait" "$before"; then
        log "step $num: no '$wait' yet, saving again"
        T send-keys -t "$ed" Escape ':w' Enter
        wait_for 15 pane_shows_new "$tool.1" "$wait" "$before" || ok=0
    fi
    (( ok )) && log "step $num: output shows '$wait'" || log "step $num: TIMEOUT waiting for '$wait'"
    sleep 1.5                       # the source pane refreshes ~1s after the output pane

    if [[ -n "$CAPTURE" ]]; then
        T capture-pane -p -t "demo:$tool.0" > "$CAPTURE/$num.editor"
        T capture-pane -p -t "demo:$tool.1" > "$CAPTURE/$num.output"
        T capture-pane -p -t "demo:$tool.2" > "$CAPTURE/$num.source"
        (( ok )) && echo ok > "$status" || echo "timeout: '$wait' never appeared" > "$status"
    fi

    if (( INTERACTIVE )); then
        if (( STEP_I < STEP_N )); then
            status_line "step $STEP_I/$STEP_N  |  edit and save freely  |  $NEXT_KEY: next step  |  C-b d: leave"
            wait_for 86400 next_pressed
        fi
    else
        local secs
        secs=$(awk -v p="$pause" -v s="$PAUSE_SCALE" 'BEGIN { print p * s }')
        [[ $secs != 0 ]] && sleep "$secs"
    fi
    return 0
}

# selected STEPFILE — is this step in --steps (or all, when none given)?
selected() {
    [[ -z "$ONLY" ]] && return 0
    local n; n=$(basename "$1"); n=${n%%_*}; n=$((10#$n))
    [[ ",$ONLY," == *",$n,"* ]]
}

drive() {
    local f rc=0
    if (( ATTACH )); then
        wait_for 30 client_present || { log "no client attached, giving up"; return 1; }
        sleep 1
    fi
    for f in "$STEPS_DIR"/[0-9][0-9]_*.repl; do selected "$f" && STEP_N=$((STEP_N + 1)); done
    for f in "$STEPS_DIR"/[0-9][0-9]_*.repl; do
        selected "$f" || continue
        run_step "$f" || rc=1
    done
    if (( INTERACTIVE )); then
        # leave the learner in the last step's REPL, to keep experimenting
        status_line "last step  |  edit and save freely  |  quit the editor (:q) or C-b d to leave"
    else
        [[ -n "$CUR" ]] && quit_tool
        T send-keys -t demo:shell -l "echo 'That was repl-acement. Thanks for watching.'"
        T send-keys -t demo:shell Enter
    fi
    log "done (rc=$rc)"
    echo "$rc" > "$WORK/driver.rc"
    return $rc
}

# the demo session: window 0 is a plain shell whose environment is the demo's
# (its own HOME so your ~/.repl.* files are untouched, vim with demo/vimrc,
# the REPLs on PATH); each REPL opens as a further window in this session.
T new-session -d -s demo -n shell -x "${SIZE%x*}" -y "${SIZE#*x}" -c "$REPO" \
    "env HOME=$(printf '%q' "$HOME_D") TMPDIR=$(printf '%q' "$TMP_D") \
         EDITOR=$(printf '%q' "vim -u $DEMO_DIR/vimrc") PATH=$(printf '%q' "$PATH_D") \
         PS1='\$ ' bash --norc --noprofile" || exit 1
T set -g status-left ' ' >/dev/null
T set -g pane-border-status top >/dev/null
T set -g pane-border-format ' #{pane_title} ' >/dev/null
status_line "repl-acement: $(basename "$(dirname "$STEPS_DIR")")/$(basename "$STEPS_DIR")"
if (( INTERACTIVE )); then
    T bind-key -n "$NEXT_KEY" run-shell "touch $(printf '%q' "$NEXT_FLAG")" >/dev/null
    T set -g status-right-length 120 >/dev/null
fi

if (( ATTACH )); then
    drive &
    DRIVER=$!
    T attach -t demo                # returns when you detach (C-b d) or the session ends
    if kill -0 "$DRIVER" 2>/dev/null; then
        kill "$DRIVER" 2>/dev/null; wait "$DRIVER" 2>/dev/null
        echo "left before the end (step $(grep -c ': typing$' "$LOG" 2>/dev/null) was open)"
        echo 0 > "$WORK/driver.rc"
    fi
    echo "driver log: see below"; cat "$LOG" 2>/dev/null
else
    drive
fi
exit "$(cat "$WORK/driver.rc" 2>/dev/null || echo 1)"
