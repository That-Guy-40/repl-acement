#!/usr/bin/env bash
##
# shellcheck disable=SC1090,SC1091
##  smoke/03_steps_complete.sh - every day 1..30 has step files under steps/, and
##  every step file is well-formed: it parses with the REPL's OWN divider (not a
##  regex of this test's), names a #DAY matching its directory and a relative
##  #FILE, has a non-empty body and a '# title' first line, carries at least one
##  positive and one negative assertion row for verify.sh, and has a reference
##  body for --solutions mode (steps/dayNN/solutions/<step>, or the file the
##  day's reference solve() leaves in a fresh fixture).
##
##  Negative control first: a planted directory with four defects must be reported.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"
source "$DIR/workoutrepl"          # _wr_divide / _wr_header; it does not launch when sourced

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
WORKOUT="$DIR/workout/bin/workout"
export WORKOUT_LIB="$DIR/workout" WORKOUT_HOME="$SANDBOX/ref"

# reference_has N FILE — does day N's reference solution leave FILE in the fixture?
reference_has() {
    local n=$1 file=$2 d; d="$WORKOUT_HOME/$(printf 'day%02d' "$n")"
    if [[ ! -d "$d" ]]; then
        ( "$WORKOUT" setup "$n" >/dev/null 2>&1 || exit 1
          . "$WORKOUT_LIB/lib/drill-lib.sh"
          . "$(drill_file "$n")"; cd -- "$d" && solve ) >/dev/null 2>&1 || return 2
    fi
    [[ -f "$d/$file" ]]
}

# scan_day DIR N — print one problem line per defect; nothing when clean
scan_day() {
    local dir=$1 n=$2 f base body data hdrs day file pos neg title rc
    shopt -s nullglob; local steps=("$dir"/[0-9][0-9]_*.repl); shopt -u nullglob
    (( ${#steps[@]} )) || { echo "$dir: no MM_<piece>.repl step files"; return; }
    for f in "${steps[@]}"; do
        base=$(basename "$f" .repl)
        body="$SANDBOX/body" data="$SANDBOX/data" hdrs="$SANDBOX/hdrs"
        grep -v '^#> ' "$f" > "$SANDBOX/in"
        _wr_divide "$SANDBOX/in" "$body" "$data" "$hdrs"
        day=$(_wr_header "$hdrs" DAY); file=$(_wr_header "$hdrs" FILE)
        [[ -n $day ]] || { echo "$base: no #DAY header"; continue; }
        [[ $(( 10#$day )) == "$n" ]] 2>/dev/null || echo "$base: #DAY $day does not match $(basename "$dir")"
        [[ -n $file ]] || { echo "$base: no #FILE header"; continue; }
        case $file in /*|../*|*/../*|*/..|..) echo "$base: #FILE $file is not relative to the fixture" ;; esac
        [[ -s $body ]] || echo "$base: empty body — nothing would be written"
        title=$(grep -v '^#> ' "$f" | head -1)
        [[ $title == '# '* ]] || echo "$base: first line is not a '# title' narration line"
        pos=$(grep -cE '^#> (out|check): ' "$f"); neg=$(grep -cE '^#> (out-not|check-not): ' "$f")
        (( pos )) || echo "$base: no positive assertion row (#> out: / #> check:)"
        (( neg )) || echo "$base: no negative assertion row (#> out-not: / #> check-not:)"
        grep -qF "#> check-not: PASS: day $(printf '%02d' "$n")" "$f" || echo "$base: no '#> check-not: PASS: day NN' row — the skeleton could already pass"
        if [[ ! -f "$dir/solutions/$base" ]]; then
            reference_has "$n" "$file"; rc=$?
            (( rc == 2 )) && echo "$base: could not build day $n's reference fixture"
            (( rc == 1 )) && echo "$base: no reference body — neither solutions/$base nor $file in the day's reference fixture"
        fi
    done
}

# --- negative control: a planted directory with four defects ---
bad="$SANDBOX/planted/day03"; mkdir -p "$bad"
printf '%s\n' '# a step with no FILE' '#DAY 3' 'echo' '#> out: x' '#> check-not: PASS: day 03' > "$bad/01_nofile.repl"
printf '%s\n' '# wrong day' '#DAY 4' '#FILE a.sh' 'echo' '#> out: x' '#> check-not: PASS: day 03' > "$bad/02_wrongday.repl"
printf '%s\n' '# no negative row' '#DAY 3' '#FILE lower.sh' 'echo' '#> out: x' > "$bad/03_noneg.repl"
printf '%s\n' '# no reference' '#DAY 3' '#FILE nothing-makes-this.sh' 'echo' '#> out: x' '#> check-not: PASS: day 03' > "$bad/04_noref.repl"
planted=$(scan_day "$bad" 3)
for want in 'no #FILE header' '#DAY 4 does not match' 'no negative assertion row' 'no reference body'; do
    if grep -qF -- "$want" <<<"$planted"; then
        pass "negative control: the scan reports a planted '$want' defect"
    else
        fail "negative control: the scan did NOT report a planted '$want' defect — it proves nothing about the real steps" "$planted"
    fi
done

# --- the real steps ---
problems=() days_ok=0
for n in $(seq 1 30); do
    d="$DIR/steps/$(printf 'day%02d' "$n")"
    [[ -d $d ]] || { problems+=("day$(printf '%02d' "$n"): no steps directory"); continue; }
    out=$(scan_day "$d" "$n")
    if [[ -n $out ]]; then while IFS= read -r l; do problems+=("$(basename "$d")/$l"); done <<<"$out"
    else days_ok=$((days_ok+1)); fi
done
total=$(find "$DIR/steps" -name '[0-9][0-9]_*.repl' | wc -l)
if (( ${#problems[@]} )); then
    fail "${#problems[@]} defect(s) in steps/ across 30 days ($days_ok days clean)" "$(printf '%s; ' "${problems[@]}")"
else
    pass "steps/: all 30 days have step files ($total pieces); each parses with the REPL's own divider, names its day and a relative #FILE, has positive and negative rows and a reference body for --solutions"
fi

summary
