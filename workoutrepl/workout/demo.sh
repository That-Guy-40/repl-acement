#!/usr/bin/env bash
# demo.sh — prove every drill is both GRADABLE and PASSABLE, and that its checker bites.
#
# For each of the 30 days, in a scratch WORKOUT_HOME:
#   1. build the fixture                               (workout setup N)
#   2. grade it UNTOUCHED — the check must FAIL        ← the negative control
#   3. apply the reference solution                    (the drill's solve())
#   4. grade it again — the check must PASS
#
# Step 2 is the half most demos skip, and it is the half that matters: a checker that
# passes an empty fixture is a checker that checks nothing, and from a green run alone
# the two are indistinguishable. Both halves are counted; the verdict is one line.
#
# Ends on exactly one of:
#   PASS: all N checks hold (30 drills: each checker bites on the fresh fixture and passes on the reference solution)
#   FAIL: k of N checks failed
#   SKIP: missing tools: …           (exit 77 — the demo refuses to grade with tools missing,
#                                     so a partial run can never read as a full one)
#
# Usage: demo.sh [N...]    — all 30 days, or just the ones named (1 7 boss2 …)
#        WORKOUT_HOME is honoured if set; otherwise a mktemp dir is used and removed.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export WORKOUT_LIB="$HERE"
# Decide the sandbox BEFORE the lib supplies its ~/workout default: an explicit
# WORKOUT_HOME is used and kept; otherwise a throwaway mktemp dir is used and removed,
# so the demo can never grade — or wipe — the learner's own ~/workout.
# shellcheck disable=SC2034  # KEEP_HOME is read inside the trap body below
if [[ -n "${WORKOUT_HOME:-}" ]]; then KEEP_HOME=1
else WORKOUT_HOME="$(mktemp -d "${TMPDIR:-/tmp}/workout-demo.XXXXXX")"; KEEP_HOME=0; fi
export WORKOUT_HOME
# shellcheck source=lib/drill-lib.sh
. "$HERE/lib/drill-lib.sh"
WORKOUT="$HERE/bin/workout"

CHECKS=0 FAILED=0
_verdict_printed=0
# demo.sh is not a tests/ file, so it owns its EXIT trap (the tests/ rule is about lib.sh).
trap 'rc=$?; (( KEEP_HOME )) || rm -rf -- "$WORKOUT_HOME"
      if (( ! _verdict_printed )) && (( rc != 0 && rc != 77 )); then echo "FAIL: demo.sh exited early (rc=$rc)"; fi' EXIT

ok()  { CHECKS=$((CHECKS+1)); printf '   [ok]  %s\n' "$*"; }
bad() { CHECKS=$((CHECKS+1)); FAILED=$((FAILED+1)); printf '   [BAD] %s\n' "$*"; }

# ── the toolset: refuse to run a partial demo ─────────────────────────────────
# Every DRILL_TOOLS entry of every selected drill must be present, or the day's check
# would end UNKNOWN and this run would be grading a subset while looking complete.
days=()
if (( $# )); then for a in "$@"; do n="$(day_num "$a")" || { echo "demo.sh: not a day: $a" >&2; exit 2; }; days+=("$n"); done
else mapfile -t days < <(seq 1 30); fi
missing=()
for n in "${days[@]}"; do
    f="$(drill_file "$n")"; [[ -r "$f" ]] || { echo "FAIL: no drill file for day $n ($f)"; _verdict_printed=1; exit 1; }
    # (an empty DRILL_TOOLS prints one blank line; a blank is not a missing tool)
    # shellcheck disable=SC1090  # the drill is chosen at run time
    while IFS= read -r t; do [[ -n "$t" ]] || continue; have "$t" || missing+=("$t"); done < <( DRILL_TOOLS=(); . "$f"; printf '%s\n' "${DRILL_TOOLS[@]}" )
done
if (( ${#missing[@]} )); then
    _verdict_printed=1
    printf 'SKIP: missing tools: %s — install them (setup-workshop.sh does) and re-run; the demo will not grade a subset\n' "$(printf '%s\n' "${missing[@]}" | sort -u | tr '\n' ' ')"
    exit 77
fi

printf 'demo — %d drill(s), sandbox %s\n' "${#days[@]}" "$WORKOUT_HOME"
for n in "${days[@]}"; do
    id="$(day_id "$n")"
    # shellcheck disable=SC1090
    title="$( . "$(drill_file "$n")"; printf '%s' "$DRILL_TITLE" )"
    printf '\n== %s — %s ==\n' "$id" "$title"
    if ! "$WORKOUT" setup "$n" >/dev/null 2>&1; then bad "$id: setup failed"; continue; fi
    # 2. negative control: the untouched fixture must NOT pass
    rc=0; out="$("$WORKOUT" check "$n" 2>&1)" || rc=$?
    if (( rc == 0 )); then bad "$id: CONTROL — the checker PASSED an untouched fixture, so it checks nothing"
    else
        nbad="$(grep -c '^   \[BAD\]' <<<"$out")"
        ok "$id: control — fresh fixture fails ($nbad assertion(s) named)"
    fi
    # 3. reference solution, in a subshell so a stray exit cannot stop the demo
    # shellcheck disable=SC1090,SC1091
    if ! ( export WORKOUT_LIB WORKOUT_HOME; . "$HERE/lib/drill-lib.sh"; D="$(drill_dir "$n")"; . "$(drill_file "$n")"; cd -- "$D" && solve ) >/dev/null 2>&1; then
        bad "$id: the reference solution exited non-zero"; continue
    fi
    # 4. and now it must pass
    rc=0; out="$("$WORKOUT" check "$n" 2>&1)" || rc=$?
    if (( rc == 0 )); then
        ok "$id: reference solution passes ($(grep -oE '\([0-9]+/[0-9]+ assertions hold\)' <<<"$out"))"
    else
        bad "$id: reference solution does NOT pass (rc=$rc):"
        grep -E '^   \[(BAD|\?\?\?)\]' <<<"$out" | head -5 | sed 's/^/          /'
    fi
done

echo
echo "----------------------------------------------------------------"
_verdict_printed=1
if (( FAILED == 0 )); then
    printf 'PASS: all %d checks hold (%d drills: each checker bites on the fresh fixture and passes on the reference solution)\n' "$CHECKS" "${#days[@]}"
    exit 0
else
    printf 'FAIL: %d of %d checks failed\n' "$FAILED" "$CHECKS"
    exit 1
fi
