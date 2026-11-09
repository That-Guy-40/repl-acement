#!/usr/bin/env bash
##
##  walk.sh — walk a day's lesson piece by piece inside workoutrepl.
##
##  Opens a tmux session with a throwaway HOME (so ~/.repl.workout and ~/workout are
##  the walk's, not yours), starts workoutrepl from a shell in it, and types each step
##  of steps/dayNN/MM_*.repl into the editor pane (vim) and saves — the save is
##  what runs the piece (bottom-left) and re-grades the day (bottom-right), exactly as
##  it would for you. Narration lives in the step files as comments, so you read it in
##  the editor while the result appears below.
##
##  Usage:
##    walk.sh --day 7                     day 7, step by step: F5 next piece, F4 previous,
##                                             and between steps the editor is yours
##    walk.sh --day 7 --timer             self-running, on each step's pause
##    walk.sh --days 1-3                  several days in one session
##    walk.sh --day 7 --steps 1,3         only those steps
##    walk.sh --day 7 --solutions         type the REFERENCE content of every piece instead
##                                             of the skeleton (what verify.sh uses to prove a
##                                             day's pieces add up to a pass)
##    walk.sh ... --fast --no-attach --capture DIR
##                                             headless, no pauses: what verify.sh runs
##
##  Step file format (MM_<piece>.repl), after repl-acement's demo/play.sh:
##    #> wait: TEXT          typed+saved, then wait for TEXT in the OUTPUT pane (default: "saved ")
##    #> pause: SECS         narration time before the next step (timer mode; default 30)
##    #> out: / #> out-not:      assertions on the OUTPUT pane (verify.sh only)
##    #> check: / #> check-not:  assertions on the CHECK pane  (verify.sh only)
##    everything else is typed into the editor verbatim: narration comments, then the
##    #DAY / #FILE / #RUN headers, then the piece's skeleton; the first line is the title.
##    A #DATA block is pasted rather than typed.
##
##  Structure follows repl-acement's demo/play.sh (Kevin Ernst et al.); the REPL it drives
##  is the workoutrepl beside this script.
##
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# the trainer: workout/ vendored beside this script (repl-acement), else the lab above it (mklab)
if [[ -x "$HERE/workout/bin/workout" ]]; then LAB="$HERE/workout"; else LAB=$(cd -- "$HERE/.." && pwd -P); fi
STEPS_ROOT="$HERE/steps"

DAYS=() FAST=0 ATTACH=1 TIMER=0 SOLUTIONS=0 CAPTURE='' ONLY='' SIZE=200x50 SOCK="workout-walk-$$"
TYPE_DELAY=${WALK_TYPE_DELAY:-0.015}
PAUSE_SCALE=${WALK_PAUSE_SCALE:-1}
NEXT_KEY=${WALK_NEXT_KEY:-F5}
PREV_KEY=${WALK_PREV_KEY:-F4}

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^##\{0,1\} \{0,1\}//' | sed '$d'; }
die() { echo "walk.sh: $*" >&2; exit 2; }

# day_list SPEC — "7" | "1-3" | "1,4,9" | "all" → one number per line
day_list() {
    local spec=$1 part
    [[ $spec == all ]] && spec=1-30
    IFS=, read -ra parts <<<"$spec"
    for part in "${parts[@]}"; do
        if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        elif [[ $part =~ ^[0-9]+$ ]]; then echo "$part"
        else die "not a day or range: $part"; fi
    done
}

while (( $# )); do
    case $1 in
        --day|--days) mapfile -t -O "${#DAYS[@]}" DAYS < <(day_list "$2"); shift ;;
        --fast)       FAST=1; TYPE_DELAY=0; PAUSE_SCALE=0 ;;
        --no-attach)  ATTACH=0 ;;
        --timer)      TIMER=1 ;;
        --solutions)  SOLUTIONS=1 ;;
        --capture)    CAPTURE=$2; shift ;;
        --socket)     SOCK=$2; shift ;;
        --steps)      ONLY=$2; shift ;;
        --size)       SIZE=$2; shift ;;
        -h|--help)    usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done
(( ${#DAYS[@]} )) || die "which day? --day N (or --days 1-3, --days all)"
(( ! TIMER && ! ATTACH && ! FAST )) && die "--no-attach needs --fast or --timer"
for need in tmux entr vim; do command -v "$need" >/dev/null 2>&1 || { echo "walk.sh: $need is required" >&2; exit 1; }; done
for d in "${DAYS[@]}"; do [[ -d "$STEPS_ROOT/$(printf 'day%02d' "$d")" ]] || die "no steps for day $d ($STEPS_ROOT/day$(printf '%02d' "$d"))"; done

# short paths: tmux sockets live here and a unix socket path caps at 108 bytes
WORK=$(mktemp -d /tmp/wwalk.XXXXXX) || exit 1
HOME_D="$WORK/home"; TMP_D="$WORK/tmp"; REF_D="$WORK/ref"; mkdir -p "$HOME_D" "$TMP_D" "$REF_D"
LOG="$WORK/driver.log"; NEXT_FLAG="$WORK/next"; PREV_FLAG="$WORK/prev"
[[ -n "$CAPTURE" ]] && mkdir -p "$CAPTURE"
PATH_D="$HERE:$LAB/bin:$PATH"

T() { tmux -L "$SOCK" "$@"; }
cleanup() { T kill-server 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

log() {
    if (( ATTACH )); then printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >> "$LOG"
    else                  printf '[walk] %s\n' "$*" >&2; fi
}
status_line() { T set -g status-right " $* " >/dev/null; }
wait_for() { local secs=$1 i; shift; for ((i = 0; i < secs * 5; i++)); do "$@" && return 0; sleep 0.2; done; return 1; }
window_open()    { [[ $(T list-panes -t "walk:workoutrepl" -F x 2>/dev/null | wc -l) -eq 3 ]]; }
# The panes' VISIBLE text is not a reliable instrument: a long run pushes the `# wrote:`
# line off the top, and a re-grade with the same verdict leaves the visible area
# identical. So the waits read the whole scrollback (-S -, wrapped lines re-joined) and
# ask whether the NUMBER of matching lines grew since before the save.
pane_hist()      { T capture-pane -p -J -S - -t "walk:workoutrepl.$1" 2>/dev/null; }
count_in()       { pane_hist "$1" | grep -cE -- "$2"; }
count_grew()     { (( $(count_in "$1" "$2") > $3 )); }
# scope_last REGEX — keep only the text from the last line matching REGEX: one run's output
scope_last()     { awk -v re="$1" '{ l[NR] = $0; if ($0 ~ re) s = NR } END { if (!s) s = 1; for (i = s; i <= NR; i++) print l[i] }'; }
WROTE_RE='^# (wrote:|\(no #FILE header).*saved [0-9:]+'
RUN_HDR_RE='^# day [0-9]+ · '
CHECK_HDR_RE='^# workout check [0-9]+ '

client_present() { [[ -n $(T list-clients 2>/dev/null) ]]; }
next_pressed()   { [[ -e "$NEXT_FLAG" || -e "$PREV_FLAG" ]]; }

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
paste_text() { printf '%s' "$2" | T load-buffer -b walk -; T paste-buffer -b walk -t "$1" -d; }

# reference_fixture N — build day N's reference solution once, under $REF_D (for --solutions)
reference_fixture() {
    local n=$1 d; d=$(printf '%s/day%02d' "$REF_D" "$n")
    [[ -d "$d" ]] && return 0
    ( export WORKOUT_LIB="$LAB" WORKOUT_HOME="$REF_D"
      "$LAB/bin/workout" setup "$n" >/dev/null 2>&1 || exit 1
      # shellcheck source=../lib/drill-lib.sh
      . "$LAB/lib/drill-lib.sh"
      # shellcheck disable=SC1090
      . "$(drill_file "$n")"; cd -- "$d" && solve ) >/dev/null 2>&1
}

open_tool() {
    log "launching workoutrepl"
    type_text walk:shell "workoutrepl"; T send-keys -t walk:shell Enter
    wait_for 20 window_open || { log "FAIL: the workoutrepl window did not open"; return 1; }
    T select-pane -t "walk:workoutrepl.0" -T "EDITOR: this piece — edit, save (:w) to run it"
    T select-pane -t "walk:workoutrepl.1" -T "OUTPUT: the piece written to the fixture and run, on every save"
    T select-pane -t "walk:workoutrepl.2" -T "CHECK: workout check N, re-graded on every save"
    sleep 1.5
}

preamble() {
    local line="# Panes: edit here, save to run | below left: the run | below right: the day re-graded"
    (( ! TIMER && ATTACH )) && line+=" | $NEXT_KEY: next piece, $PREV_KEY: previous"
    printf '%s' "$line"
}

STEP_I=0 STEP_N=0
# run_step FILE — type a step, save, wait for both panes, capture
run_step() {
    local file=$1 base num day wait='saved ' pause=30 line body=() key val title='' fileh=''
    base=$(basename "$file" .repl); num=${base%%_*}
    day=$(basename "$(dirname "$file")"); day=${day#day}; day=$((10#$day))
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == '#> '* ]]; then
            key=${line#\#> }; val=${key#*: }; key=${key%%:*}
            case $key in wait) wait=$val ;; pause) pause=$val ;; esac
        else
            [[ -z $title ]] && title=${line#\# }
            [[ $line =~ ^#[Ff][Ii][Ll][Ee][:[:space:]]+(.*)$ ]] && fileh=${BASH_REMATCH[1]}
            body+=("$line")
        fi
    done < "$file"
    STEP_I=$((STEP_I + 1))
    local tag; tag=$(printf 'day%02d-%s' "$day" "$num")
    local status="$CAPTURE/$tag.status"

    # --solutions: the body after the last header becomes the reference content of #FILE
    if (( SOLUTIONS )); then
        local src="" sol; sol="$(dirname "$file")/solutions/$base"
        if [[ -f "$sol" ]]; then src=$sol
        elif [[ -n "$fileh" ]]; then
            reference_fixture "$day" || { log "FAIL $base: could not build day $day's reference"; [[ -n $CAPTURE ]] && echo "failed: no reference fixture" > "$status"; return 1; }
            src=$(printf '%s/day%02d/%s' "$REF_D" "$day" "$fileh")
        fi
        [[ -n "$src" && -f "$src" ]] || { log "FAIL $base: no reference content for #FILE '$fileh'"; [[ -n $CAPTURE ]] && echo "failed: no reference for $fileh" > "$status"; return 1; }
        local kept=() i last=-1
        for i in "${!body[@]}"; do [[ ${body[i]} =~ ^#([Dd][Aa][Yy]|[Ff][Ii][Ll][Ee]|[Rr][Uu][Nn]|[Mm][Oo][Dd][Ee]|[Tt][Ii][Mm][Ee][Oo][Uu][Tt]|[Ff][Rr][Ee][Ss][Hh])[:[:space:]] ]] && last=$i; done
        for (( i = 0; i <= last; i++ )); do kept+=("${body[i]}"); done
        local sl; while IFS= read -r sl || [[ -n $sl ]]; do kept+=("$sl"); done < "$src"
        body=("${kept[@]}")
    fi

    if (( ! TIMER && ATTACH )); then status_line "day $day · piece $STEP_I/$STEP_N  |  typing…"; rm -f "$NEXT_FLAG" "$PREV_FLAG"; fi

    local typed='' pasted='' in_data=0
    for line in "${body[@]}"; do
        if (( ! in_data )) && [[ $line =~ ^#[[:space:]]*[Dd][Aa][Tt][Aa][:[:space:]]*$ ]]; then in_data=1; fi
        if (( in_data )); then pasted+="$line"$'\n'; else typed+="$line"$'\n'; fi
    done
    pasted=${pasted%$'\n'}
    [[ -z "$pasted" ]] && typed=${typed%$'\n'}
    typed="$(preamble)"$'\n'"$typed"

    local ed="walk:workoutrepl.0" before1 before2 wait_re verdict_re
    # the default wait is the runner's own `# wrote: … saved HH:MM:SS` line; a custom
    # `#> wait:` text is matched literally
    if [[ $wait == 'saved ' ]]; then wait_re=$WROTE_RE; else wait_re=$(printf '%s' "$wait" | sed 's/[][\\.*^$/]/\\&/g'); fi
    verdict_re="^(PASS|FAIL|UNKNOWN): day $(printf '%02d' "$day")"
    before1=$(count_in 1 "$wait_re"); before2=$(count_in 2 "$verdict_re")
    log "$tag: typing"
    T send-keys -t "$ed" Escape
    T send-keys -t "$ed" -l 'ggdG'
    T send-keys -t "$ed" -l 'i'
    if (( FAST )); then paste_text "$ed" "$typed"; else type_text "$ed" "$typed"; fi
    [[ -n "$pasted" ]] && paste_text "$ed" "$pasted"
    T send-keys -t "$ed" Escape
    T send-keys -t "$ed" -l ':w'; T send-keys -t "$ed" Enter
    T send-keys -t "$ed" -l 'gg'

    local ok=1
    if ! wait_for 25 count_grew 1 "$wait_re" "$before1"; then
        log "$tag: no new '$wait' yet, saving again"
        T send-keys -t "$ed" Escape ':w' Enter
        wait_for 15 count_grew 1 "$wait_re" "$before1" || ok=0
    fi
    # the check pane re-grades after the run: a NEW verdict line must appear
    wait_for 40 count_grew 2 "$verdict_re" "$before2" || { ok=0; log "$tag: the CHECK pane never re-graded"; }
    (( ok )) && log "$tag: output shows a new '$wait' and the day was re-graded" || log "$tag: TIMEOUT"
    sleep 0.5

    if [[ -n "$CAPTURE" ]]; then
        # one step's captures hold THIS run only: from the runner's `# day NN ·` header and
        # the checker's `# workout check N` header to the end of the scrollback
        T capture-pane -p -t "walk:workoutrepl.0" > "$CAPTURE/$tag.editor"
        pane_hist 1 | scope_last "$RUN_HDR_RE"   > "$CAPTURE/$tag.output"
        pane_hist 2 | scope_last "$CHECK_HDR_RE" > "$CAPTURE/$tag.check"
        (( ok )) && echo ok > "$status" || echo "timeout: no new '$wait' line or no re-grade appeared" > "$status"
    fi

    if (( ! TIMER && ATTACH )); then
        if (( STEP_I < STEP_N )); then
            status_line "day $day · piece $STEP_I/$STEP_N  |  edit and save freely  |  $NEXT_KEY: next piece  $PREV_KEY: previous  |  C-b d: leave"
            wait_for 86400 next_pressed
        fi
    else
        local secs; secs=$(awk -v p="$pause" -v s="$PAUSE_SCALE" 'BEGIN { print p * s }')
        [[ $secs != 0 ]] && sleep "$secs"
    fi
    return 0
}

selected() { [[ -z "$ONLY" ]] && return 0; local n; n=$(basename "$1"); n=${n%%_*}; n=$((10#$n)); [[ ",$ONLY," == *",$n,"* ]]; }

drive() {
    local d f rc=0 files=() i
    if (( ATTACH )); then wait_for 30 client_present || { log "no client attached, giving up"; return 1; }; sleep 1; fi
    for d in "${DAYS[@]}"; do
        for f in "$STEPS_ROOT/$(printf 'day%02d' "$d")"/[0-9][0-9]_*.repl; do selected "$f" && files+=("$f"); done
    done
    STEP_N=${#files[@]}
    (( STEP_N )) || { log "no steps selected"; return 1; }
    open_tool || return 1
    i=0
    while (( i < STEP_N )); do
        run_step "${files[i]}" || rc=1
        if (( ! TIMER && ATTACH )) && [[ -e "$PREV_FLAG" ]]; then
            rm -f "$PREV_FLAG"; (( i > 0 )) && i=$((i - 1)); STEP_I=$((STEP_I - 2)); (( STEP_I < 0 )) && STEP_I=0
        else
            i=$((i + 1))
        fi
    done
    if (( ! TIMER && ATTACH )); then
        status_line "last piece  |  edit and save freely  |  quit vim (:q) or C-b d to leave"
    else
        T send-keys -t "walk:workoutrepl.0" Escape ':q!' Enter
        sleep 0.5
    fi
    log "done (rc=$rc)"; echo "$rc" > "$WORK/driver.rc"; return $rc
}

T new-session -d -s walk -n shell -x "${SIZE%x*}" -y "${SIZE#*x}" -c "$LAB" \
    "env HOME=$(printf '%q' "$HOME_D") TMPDIR=$(printf '%q' "$TMP_D") WORKOUT_LIB=$(printf '%q' "$LAB") \
         WORKOUT_HOME=$(printf '%q' "$HOME_D/workout") EDITOR=$(printf '%q' "vim -u $HERE/vimrc") \
         PATH=$(printf '%q' "$PATH_D") PS1='\$ ' bash --norc --noprofile" || exit 1
T set -g history-limit 50000 >/dev/null    # the waits count lines in the scrollback
T set -g status-left ' ' >/dev/null
T set -g pane-border-status top >/dev/null
T set -g pane-border-format ' #{pane_title} ' >/dev/null
T set -g status-right-length 140 >/dev/null
status_line "the 30-day workout · walk.sh"
if (( ! TIMER && ATTACH )); then
    T bind-key -n "$NEXT_KEY" run-shell "touch $(printf '%q' "$NEXT_FLAG")" >/dev/null
    T bind-key -n "$PREV_KEY" run-shell "touch $(printf '%q' "$PREV_FLAG")" >/dev/null
fi

if (( ATTACH )); then
    drive & DRIVER=$!
    T attach -t walk
    if kill -0 "$DRIVER" 2>/dev/null; then kill "$DRIVER" 2>/dev/null; wait "$DRIVER" 2>/dev/null; echo "left before the end"; echo 0 > "$WORK/driver.rc"; fi
    echo "driver log:"; cat "$LOG" 2>/dev/null
else
    drive
fi
exit "$(cat "$WORK/driver.rc" 2>/dev/null || echo 1)"
