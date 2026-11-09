#!/usr/bin/env bash
##
##  verify.sh — prove, headlessly, that a day's step files do what they claim
##  inside workoutrepl: each piece typed into the editor is written and run (OUTPUT
##  pane) and the day is re-graded (CHECK pane), and the panes show what the step's
##  assertion rows say they must — and must NOT.
##
##  Two modes, both required for a day to count as verified:
##    skeleton    (default)  the pieces as the learner first sees them: each step's
##                           `#> out:` / `#> out-not:` / `#> check:` / `#> check-not:`
##                           rows must hold, and no step may end the day on PASS
##    --solutions            the reference content typed in place of every skeleton:
##                           every piece must be written and run, and the LAST piece
##                           must leave the CHECK pane on `PASS: day NN`
##
##  Usage:  verify.sh --day 7 [--solutions] [--keep DIR] [--days 1-30]
##
##  Verdict: one PASS/FAIL/UNKNOWN line (exit 0/1/77). Before it looks at a real
##  day it runs its own negative control: a planted failing row must be reported, or
##  the grader is not attached to anything.
##
##  After repl-acement's demo/verify.sh (Kevin Ernst et al.).
##
set -uo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
STEPS_ROOT="$HERE/steps"

DAYS=() SOLUTIONS=0 KEEP=''
day_list() {
    local spec=$1 part parts
    [[ $spec == all ]] && spec=1-30
    IFS=, read -ra parts <<<"$spec"
    for part in "${parts[@]}"; do
        if [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        elif [[ $part =~ ^[0-9]+$ ]]; then echo "$part"
        else echo "verify.sh: not a day or range: $part" >&2; exit 2; fi
    done
}
while (( $# )); do
    case $1 in
        --day|--days) mapfile -t -O "${#DAYS[@]}" DAYS < <(day_list "$2"); shift ;;
        --solutions)  SOLUTIONS=1 ;;
        --keep)       KEEP=$2; shift ;;
        -h|--help)    sed -n '2,/^set -uo/p' "$0" | sed 's/^##\{0,1\} \{0,1\}//' | sed '$d'; exit 0 ;;
        *) echo "verify.sh: unknown option $1" >&2; exit 2 ;;
    esac; shift
done
(( ${#DAYS[@]} )) || { echo "verify.sh: which day? --day N" >&2; exit 2; }
MODE=skeleton; (( SOLUTIONS )) && MODE=solutions

FAILS=() ASSERTS=0
note() { printf '  - %s\n' "$*"; }
flunk() { FAILS+=("$*"); printf '  ✗ %s\n' "$*"; }
contains() { grep -qF -- "$2" <<<"$1"; }

# ── negative control: the grader must bite on a planted bad row ────────────────────
# grade_step STEP CAPDIR MODE DAY IS_LAST → prints "ok N" or lines "FAIL: …"
grade_step() {
    local step=$1 cap=$2 mode=$3 day=$4 last=$5
    local base tag out chk st line key val n=0 fileh='' dayh='' pos=0 neg=0
    base=$(basename "$step" .repl); tag=$(printf 'day%02d-%s' "$day" "${base%%_*}")
    st=$(cat "$cap/$tag.status" 2>/dev/null || echo "missing: no capture for $tag")
    [[ $st == ok ]] || { echo "FAIL: $base — the walk did not complete the step ($st)"; return; }
    out=$(cat "$cap/$tag.output" 2>/dev/null); chk=$(cat "$cap/$tag.check" 2>/dev/null)
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ ^#[Dd][Aa][Yy][:[:space:]]+(.*)$ ]] && dayh=${BASH_REMATCH[1]}
        [[ $line =~ ^#[Ff][Ii][Ll][Ee][:[:space:]]+(.*)$ ]] && fileh=${BASH_REMATCH[1]}
        [[ $line == '#> '* ]] || continue
        key=${line#\#> }; val=${key#*: }; key=${key%%:*}
        if [[ $mode == skeleton ]]; then
            case $key in
                out)       n=$((n+1)); pos=1; contains "$out" "$val" || echo "FAIL: $base — OUTPUT pane lacks '$val'" ;;
                out-not)   n=$((n+1)); neg=1; contains "$out" "$val" && echo "FAIL: $base — OUTPUT pane shows '$val' (must not)" ;;
                check)     n=$((n+1)); pos=1; contains "$chk" "$val" || echo "FAIL: $base — CHECK pane lacks '$val'" ;;
                check-not) n=$((n+1)); neg=1; contains "$chk" "$val" && echo "FAIL: $base — CHECK pane shows '$val' (must not)" ;;
            esac
        fi
    done < "$step"
    [[ -n $fileh ]] || echo "FAIL: $base — no #FILE header"
    [[ $(printf '%d' "$((10#${dayh:-0}))" 2>/dev/null) == "$day" ]] || echo "FAIL: $base — #DAY '$dayh' does not match its day$(printf '%02d' "$day")/ directory"
    local wrote; wrote=$(printf 'wrote:   day%02d/%s' "$day" "$fileh")
    n=$((n+1)); contains "$out" "$wrote" || echo "FAIL: $base — OUTPUT pane never showed '$wrote'"
    if [[ $mode == skeleton ]]; then
        (( pos )) || echo "FAIL: $base — no positive assertion row (#> out: / #> check:)"
        (( neg )) || echo "FAIL: $base — no negative assertion row (#> out-not: / #> check-not:)"
        n=$((n+1)); contains "$chk" "$(printf 'PASS: day %02d' "$day")" && echo "FAIL: $base — the SKELETON already passes day $day; the piece asks nothing of the learner"
    else
        n=$((n+1)); grep -qE '^# exit: +[0-9]+' <<<"$out" || grep -qE '^# \(no #FILE' <<<"$out" || echo "FAIL: $base — OUTPUT pane shows no '# exit:' line; the piece was not run"
        if (( last )); then
            n=$((n+1)); contains "$chk" "$(printf 'PASS: day %02d' "$day")" || echo "FAIL: $base — after the last reference piece the CHECK pane does not show 'PASS: day $(printf '%02d' "$day")'"
        fi
    fi
    echo "ok $n"
}

self_check() {
    local t; t=$(mktemp -d "${TMPDIR:-/tmp}/wrverify-self.XXXXXX") || return 1
    mkdir -p "$t/steps" "$t/cap"
    printf '%s\n' '# a planted step' '#DAY 3' '#FILE x.sh' 'echo' '#> out: present-text' '#> out: MISSING-TEXT' '#> check-not: [ok] forbidden' > "$t/steps/01_x.repl"
    echo ok > "$t/cap/day03-01.status"
    printf '%s\n' '# wrote:   day03/x.sh  (mode 644, 1 lines)  saved 00:00:00' '# exit:    0' 'present-text' > "$t/cap/day03-01.output"
    printf '%s\n' '[ok] forbidden' 'FAIL: day 03 — x (1 of 2 assertions failed)' > "$t/cap/day03-01.check"
    local r; r=$(grade_step "$t/steps/01_x.repl" "$t/cap" skeleton 3 1)
    local bad=0
    grep -q "OUTPUT pane lacks 'MISSING-TEXT'" <<<"$r" || { echo "verify.sh: SELF-CHECK FAILED — a missing #> out: text was not reported"; bad=1; }
    grep -q "CHECK pane shows '\[ok\] forbidden'" <<<"$r" || { echo "verify.sh: SELF-CHECK FAILED — a present #> check-not: text was not reported"; bad=1; }
    grep -q "no negative" <<<"$r" && { echo "verify.sh: SELF-CHECK FAILED — a step with a check-not row was called negative-less"; bad=1; }
    grep -q "FAIL: .*present-text" <<<"$r" && { echo "verify.sh: SELF-CHECK FAILED — a present text was reported missing"; bad=1; }
    # solutions mode: a missing PASS on the last step must be reported
    r=$(grade_step "$t/steps/01_x.repl" "$t/cap" solutions 3 1)
    grep -q "does not show 'PASS: day 03'" <<<"$r" || { echo "verify.sh: SELF-CHECK FAILED — solutions mode did not report the missing PASS"; bad=1; }
    rm -rf "$t"
    return $bad
}

for need in tmux entr vim; do
    command -v "$need" >/dev/null 2>&1 || { echo "UNKNOWN: $need is not installed — the REPL cannot be driven, nothing verified"; exit 77; }
done
[[ -x "$HERE/walk.sh" && -x "$HERE/workoutrepl" ]] || { echo "FAIL: walk.sh or workoutrepl is missing or not executable"; exit 1; }
self_check || { echo "FAIL: verify.sh's own negative control did not bite — the grader proves nothing"; exit 1; }
note "negative control: a planted missing text, a planted forbidden text and a missing PASS were all reported"

CAP_ROOT=${KEEP:-$(mktemp -d "${TMPDIR:-/tmp}/wrverify.XXXXXX")}
cleanup() { [[ -z $KEEP ]] && rm -rf "$CAP_ROOT"; }
trap cleanup EXIT

STEPS_TOTAL=0
for d in "${DAYS[@]}"; do
    dd=$(printf 'day%02d' "$d"); sdir="$STEPS_ROOT/$dd"
    [[ -d $sdir ]] || { flunk "$dd: no step files under steps/$dd/"; continue; }
    mapfile -t steps < <(ls "$sdir"/[0-9][0-9]_*.repl 2>/dev/null)
    (( ${#steps[@]} )) || { flunk "$dd: no MM_*.repl step files"; continue; }
    cap="$CAP_ROOT/$dd-$MODE"; mkdir -p "$cap"
    args=(--day "$d" --fast --no-attach --capture "$cap"); (( SOLUTIONS )) && args+=(--solutions)
    "$HERE/walk.sh" "${args[@]}" > "$cap/walk.log" 2>&1; wrc=$?
    (( wrc == 0 )) || note "$dd: walk.sh exited $wrc (see $cap/walk.log)"
    i=0
    for s in "${steps[@]}"; do
        i=$((i+1)); last=0; (( i == ${#steps[@]} )) && last=1
        r=$(grade_step "$s" "$cap" "$MODE" "$d" "$last")
        while IFS= read -r l; do
            case $l in
                "ok "*) ASSERTS=$((ASSERTS + ${l#ok })) ;;
                FAIL:*) flunk "$dd/${l#FAIL: }" ;;
            esac
        done <<<"$r"
        STEPS_TOTAL=$((STEPS_TOTAL+1))
    done
    note "$dd: ${#steps[@]} pieces walked in $MODE mode"
done

if (( ${#FAILS[@]} )); then
    echo "FAIL: repl steps ($MODE) — ${#FAILS[@]} assertion(s) failed over $STEPS_TOTAL pieces; first: ${FAILS[0]}"
    [[ -n $KEEP ]] && echo "  captures kept under $KEEP"
    exit 1
fi
echo "PASS: repl steps ($MODE) — $STEPS_TOTAL pieces of day(s) ${DAYS[*]} typed into the editor pane, each written+run in the OUTPUT pane and re-graded in the CHECK pane; $ASSERTS assertions hold"
