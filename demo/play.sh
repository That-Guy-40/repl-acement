#!/usr/bin/env bash
##
##  demo/play.sh — self-running playback of the fraud-triage demo.
##
##  Opens a tmux session, starts each REPL from a shell inside it (so the
##  audience sees `$ awkrepl` typed, and the REPL opens as a window), then
##  types every step of demo/steps/*.repl into the real editor (vim) and
##  saves, which is what makes the output pane re-run. Narration lives in
##  the step files as comments, so it shows in the editor pane.
##
##  Usage:
##    demo/play.sh                 play it, attached to this terminal
##    demo/play.sh --steps 1,4,9   only those steps
##    demo/play.sh --fast --no-attach --capture DIR
##                                 headless, no pauses: what verify.sh runs
##
##  Step file format (demo/steps/NN_*.repl):
##    #> tool: awkrepl          which REPL (window name == command name)
##    #> needs: real            needs demo/data/real/creditcard.csv (@REAL@)
##    #> needs: yq-mikefarah    needs Mike Farah's Go yq on PATH
##    #> wait: TEXT             typed+saved, then wait for TEXT in the output pane
##    #> pause: SECS            narration time before the next step
##    #> must: / #> not: / #> source:   assertions, used by verify.sh only
##    everything else is typed into the editor verbatim; the first line is
##    the step's title; a @CSV@ line is replaced by data/transactions.csv
##    and the #DATA block is pasted rather than typed.
##
set -uo pipefail

DEMO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd "$DEMO_DIR/.." && pwd -P)
CSV="$DEMO_DIR/data/transactions.csv"
REAL="$DEMO_DIR/data/real/creditcard.csv"

FAST=0 ATTACH=1 CAPTURE='' SOCK="demo-$$" ONLY='' SIZE=200x50
TYPE_DELAY=${DEMO_TYPE_DELAY:-0.02}      # seconds per typed character
PAUSE_SCALE=${DEMO_PAUSE_SCALE:-1}       # multiplier on each step's pause

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^##\{0,1\} \{0,1\}//' | sed '$d'; }

while (( $# )); do
    case $1 in
        --fast)      FAST=1; TYPE_DELAY=0; PAUSE_SCALE=0 ;;
        --no-attach) ATTACH=0 ;;
        --capture)   CAPTURE=$2; shift ;;
        --socket)    SOCK=$2; shift ;;
        --steps)     ONLY=$2; shift ;;
        --size)      SIZE=$2; shift ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "play.sh: unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

for need in tmux entr vim; do
    command -v "$need" >/dev/null 2>&1 || { echo "play.sh: $need is required" >&2; exit 1; }
done
[[ -f "$CSV" ]] || { echo "play.sh: missing $CSV" >&2; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/repl-demo.XXXXXX") || exit 1
HOME_D="$WORK/home"; TMP_D="$WORK/tmp"; mkdir -p "$HOME_D" "$TMP_D"
LOG="$WORK/driver.log"
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

# wait_for SECS CMD... — poll CMD every 0.2s until it succeeds or SECS pass
wait_for() {
    local secs=$1 i; shift
    for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done
    return 1
}
window_open()   { [[ $(T list-panes -t "demo:$1" -F x 2>/dev/null | wc -l) -eq 3 ]]; }
window_gone()   { ! T list-windows -t demo -F '#{window_name}' 2>/dev/null | grep -qxF -- "$1"; }
pane_has()      { T capture-pane -p -t "demo:$1" 2>/dev/null | grep -qF -- "$2"; }
client_present(){ [[ -n $(T list-clients 2>/dev/null) ]]; }
has_mf_yq()     { yq --version 2>&1 | grep -qi mikefarah; }

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

open_tool() {
    local tool=$1
    [[ -n "$CUR" ]] && quit_tool
    log "launching $tool"
    type_text demo:shell "$tool"
    T send-keys -t demo:shell Enter
    wait_for 20 window_open "$tool" || { log "FAIL: $tool window did not open"; return 1; }
    sleep 1.5                       # vim up, entr armed
    CUR=$tool
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
    local file=$1 num base tool wait pause=30 needs=() line body=() key val
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
            body+=("$line")
        fi
    done < "$file"

    local status="$CAPTURE/$num.status"
    for val in "${needs[@]+"${needs[@]}"}"; do
        case $val in
            real)         [[ -f "$REAL" ]] || { log "SKIP $base: $REAL not fetched (demo/fetch-deps.sh)"; [[ -n $CAPTURE ]] && echo "skipped: real dataset not fetched" > "$status"; return 0; } ;;
            yq-mikefarah) PATH="$PATH_D" has_mf_yq  || { log "SKIP $base: yq on PATH is not Mike Farah's Go yq (demo/fetch-deps.sh)"; [[ -n $CAPTURE ]] && echo "skipped: Mike Farah yq not on PATH" > "$status"; return 0; } ;;
        esac
    done

    [[ "$CUR" == "$tool" ]] || open_tool "$tool" || { [[ -n $CAPTURE ]] && echo "failed: $tool did not open" > "$status"; return 1; }

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

    local ed="demo:$tool.0"
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
    if ! wait_for 20 pane_has "$tool.1" "$wait"; then
        log "step $num: no '$wait' yet, saving again"
        T send-keys -t "$ed" Escape ':w' Enter
        wait_for 15 pane_has "$tool.1" "$wait" || ok=0
    fi
    (( ok )) && log "step $num: output shows '$wait'" || log "step $num: TIMEOUT waiting for '$wait'"
    sleep 1.5                       # the source pane refreshes ~1s after the output pane

    if [[ -n "$CAPTURE" ]]; then
        T capture-pane -p -t "demo:$tool.0" > "$CAPTURE/$num.editor"
        T capture-pane -p -t "demo:$tool.1" > "$CAPTURE/$num.output"
        T capture-pane -p -t "demo:$tool.2" > "$CAPTURE/$num.source"
        (( ok )) && echo ok > "$status" || echo "timeout: '$wait' never appeared" > "$status"
    fi

    local secs
    secs=$(awk -v p="$pause" -v s="$PAUSE_SCALE" 'BEGIN { print p * s }')
    [[ $secs != 0 ]] && sleep "$secs"
    return 0
}

drive() {
    local f rc=0
    if (( ATTACH )); then
        wait_for 30 client_present || { log "no client attached, giving up"; return 1; }
        sleep 1
    fi
    for f in "$DEMO_DIR"/steps/[0-9][0-9]_*.repl; do
        if [[ -n "$ONLY" ]]; then
            local n; n=$(basename "$f"); n=${n%%_*}; n=$((10#$n))
            [[ ",$ONLY," == *",$n,"* ]] || continue
        fi
        run_step "$f" || rc=1
    done
    [[ -n "$CUR" ]] && quit_tool
    T send-keys -t demo:shell -l "echo 'That was repl-acement. Thanks, JR.'"
    T send-keys -t demo:shell Enter
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
T set -g status-right ' repl-acement demo ' >/dev/null
T set -g status-left ' ' >/dev/null

if (( ATTACH )); then
    drive &
    DRIVER=$!
    T attach -t demo                # returns when you detach (C-b d) or the session ends
    kill "$DRIVER" 2>/dev/null; wait "$DRIVER" 2>/dev/null
    echo "driver log: see below"; cat "$LOG" 2>/dev/null
else
    drive
fi
exit "$(cat "$WORK/driver.rc" 2>/dev/null || echo 1)"
