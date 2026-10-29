#!/usr/bin/env bash
##
##  demo/verify.sh — run the demo headless and check every pane of every step.
##
##  Runs play.sh --fast --no-attach with a capture directory, then for each
##  step reads its '#> must:', '#> not:' and '#> source:' directives and
##  checks them against what the panes actually showed:
##    editor pane (0): must show the step's title line (the first typed line)
##    output pane (1): must contain every 'must:' and none of the 'not:' texts
##    source pane (2): must contain the 'source:' text
##  A step that could not run (dataset or yq missing) is UNKNOWN, not PASS.
##  Before any of that, the assertion helpers are run against a known-bad
##  capture and must fail: an all-PASS result from checks that can't fail is
##  worthless.
##
##  Usage: demo/verify.sh [--dir DIR] [--steps 1,4,9] [--keep]
##    --dir DIR   verify another step directory (default demo/steps)
##
set -uo pipefail
DEMO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

ONLY='' KEEP=0 STEPS_DIR="$DEMO_DIR/steps"
while (( $# )); do
    case $1 in
        --dir)   STEPS_DIR=$(cd "$2" && pwd -P) || exit 2; shift ;;
        --steps) ONLY=$2; shift ;;
        --keep)  KEEP=1 ;;
        *) echo "verify.sh: unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

CAP=$(mktemp -d "${TMPDIR:-/tmp}/repl-demo-verify.XXXXXX") || exit 1
finish() { if (( KEEP )); then echo "captures kept in $CAP"; else rm -rf "$CAP"; fi; }
trap finish EXIT

PASS=0 FAIL=0 UNKNOWN=0
pass()    { PASS=$((PASS + 1));       printf '  PASS: %s\n' "$1"; }
fail()    { FAIL=$((FAIL + 1));       printf '  FAIL: %s\n' "$1"; [[ -n ${2:-} ]] && printf '        %s\n' "$2"; }
unknown() { UNKNOWN=$((UNKNOWN + 1)); printf '  UNKNOWN: %s\n' "$1"; }

# contains FILE TEXT — fixed-string search of a captured pane
contains() { grep -qF -- "$2" "$1"; }

# --- negative control: the helpers must be able to fail ----------------------
printf 'alpha\nbeta\n' > "$CAP/selfcheck"
if contains "$CAP/selfcheck" "gamma"; then
    echo "verify.sh: self-check broken: 'contains' matched text that is not there" >&2; exit 3
fi
if ! contains "$CAP/selfcheck" "beta"; then
    echo "verify.sh: self-check broken: 'contains' missed text that is there" >&2; exit 3
fi

# --- run the demo headless ---------------------------------------------------
args=(--fast --no-attach --capture "$CAP" --socket "demo-verify-$$" --dir "$STEPS_DIR")
[[ -n "$ONLY" ]] && args+=(--steps "$ONLY")
echo "==> playing $STEPS_DIR headless"
bash "$DEMO_DIR/play.sh" "${args[@]}"
echo "    play.sh exit status: $?"

# --- check every step --------------------------------------------------------
for f in "$STEPS_DIR"/[0-9][0-9]_*.repl; do
    base=$(basename "$f" .repl); num=${base%%_*}
    if [[ -n "$ONLY" ]]; then
        n=$((10#$num)); [[ ",$ONLY," == *",$n,"* ]] || continue
    fi
    echo "==> $base"
    status=$(cat "$CAP/$num.status" 2>/dev/null || echo "missing: no status written")
    case $status in
        ok) ;;
        skipped:*) unknown "$base not run (${status#skipped: })"; continue ;;
        *) fail "$base did not complete: $status" "$(tail -5 "$CAP/$num.output" 2>/dev/null | tr '\n' '|')"; continue ;;
    esac

    title=''; musts=(); nots=(); sources=()
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == '#> '* ]]; then
            key=${line#\#> }; val=${key#*: }; key=${key%%:*}
            case $key in
                must)   musts+=("$val") ;;
                not)    nots+=("$val") ;;
                source) sources+=("$val") ;;
            esac
        elif [[ -z $title ]]; then
            title=${line#\# }
        fi
    done < "$f"

    # editor pane: the title line was typed and is visible
    if contains "$CAP/$num.editor" "${title:0:60}"; then
        pass "editor pane shows the step title"
    else
        fail "editor pane does not show the title '${title:0:60}'" "$(head -3 "$CAP/$num.editor" | tr '\n' '|')"
    fi
    # editor pane: the one-line pane guide the driver types above the title
    if contains "$CAP/$num.editor" "# Panes: edit here, save to run | below left: output | below right:"; then
        pass "editor pane shows the pane guide"
    else
        fail "editor pane lacks the pane guide" "$(head -2 "$CAP/$num.editor" | tr '\n' '|')"
    fi
    # output pane
    for m in "${musts[@]+"${musts[@]}"}"; do
        if contains "$CAP/$num.output" "$m"; then pass "output has: $m"
        else fail "output lacks: $m" "$(grep -v '^$' "$CAP/$num.output" | tail -8 | tr '\n' '|')"; fi
    done
    for m in "${nots[@]+"${nots[@]}"}"; do
        if contains "$CAP/$num.output" "$m"; then fail "output must not show: $m"
        else pass "output hides: $m"; fi
    done
    (( ${#nots[@]} )) || fail "$base has no 'not:' row, so its checks cannot fail on over-matching"
    # source pane
    for m in "${sources[@]+"${sources[@]}"}"; do
        if contains "$CAP/$num.source" "$m"; then pass "source pane has: $m"
        else fail "source pane lacks: $m" "$(grep -v '^$' "$CAP/$num.source" | head -5 | tr '\n' '|')"; fi
    done
done

echo
echo "verify: $PASS passed, $FAIL failed, $UNKNOWN unknown"
(( PASS + FAIL + UNKNOWN > 0 )) || { echo "verify: nothing was checked" >&2; exit 1; }
(( FAIL == 0 ))
