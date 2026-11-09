#!/usr/bin/env bash
# drill-lib.sh — the helpers every drill is written against, and the contract they share.
#
# A drill is a file drills/dayNN.sh that, when sourced, defines:
#
#   DRILL_TITLE="…"            one line, printed in `workout list`
#   DRILL_WEEK=N               1..4 (day 29/30 are week 5, the cool-down)
#   DRILL_TOOLS=(…)            externals it needs beyond bash + coreutils (may be empty)
#   brief()                    prints the task — the WHOLE task, so nothing is hidden
#   hint()                     optional: a nudge, not a solution
#   setup()                    builds the fixture inside $D (already created, empty)
#   check()                    asserts the OUTCOME with the expect_* helpers below
#   solve()                    the reference solution, run with cwd=$D
#
# Three rules the helpers enforce or make easy:
#
#   1. CHECK THE OUTCOME, NOT THE MECHANISM. A check asks "does lower.sh lowercase a
#      name with a newline in it?", never "does lower.sh contain `find -print0`?". The
#      learner may reach the state any way they like; the fixture is what is graded.
#      (The one deliberate exception — day 05 runs the script with an EMPTY PATH — is
#      still an outcome: "works with no externals" is a property of the program.)
#
#   2. EVERY FAILED ASSERTION NAMES WHAT IS WRONG, expected vs actual where there is one.
#      A learner reading `[BAD]` alone has learned nothing; the line has to say which
#      invariant failed. `bad` lines are collected and the verdict counts them.
#
#   3. A CHECKER THAT CANNOT DECIDE SAYS SO. `unknown "…"` records that an assertion was
#      NOT verified (a tool is missing on this machine) — it is neither a pass nor a
#      fail, the verdict reports it by name, and a day with an UNKNOWN in it is not
#      passed. "I could not check this" must never render as "this is fine".
#
# Every drill lives entirely inside $D (= $WORKOUT_HOME/dayNN). Nothing here writes
# outside it — tests/test-solutions-stay-in-the-sandbox.sh plants a canary around the
# sandbox and fails the suite if any setup or solve reaches past it.
set -uo pipefail

# ── where things are ──────────────────────────────────────────────────────────
# WORKOUT_LIB: the lab directory (bin/, lib/, drills/). WORKOUT_HOME: the learner's
# sandbox. Both overridable so the tests can run against a scratch tree.
WORKOUT_LIB="${WORKOUT_LIB:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
WORKOUT_HOME="${WORKOUT_HOME:-$HOME/workout}"
export WORKOUT_LIB WORKOUT_HOME

# The drills assume GNU tools and the C collation (`sort`, `comm`, `[a-z]` all depend on
# it). Set once here so every drill, every check and every reference solution agree.
export LC_ALL=C

# ── naming ────────────────────────────────────────────────────────────────────
# Boss battles are days 7/14/21/28, and they have names. The cetacean theme is the
# article's own conceit (the author had Claude name the weekly tests after whales);
# these four are this lab's, not the article's.
# shellcheck disable=SC2034  # read through ${!var}
BOSS_NAME_7="Cobalt Beluga"
# shellcheck disable=SC2034  # read through ${!var}
BOSS_NAME_14="Vermilion Narwhal"
# shellcheck disable=SC2034  # read through ${!var}
BOSS_NAME_21="Ochre Orca"
# shellcheck disable=SC2034  # read through ${!var}
BOSS_NAME_28="Indigo Fin Whale"
# shellcheck disable=SC2034  # read through ${!var}
WEEK_NAME_1="Hands — the line editor and the expansions"
# shellcheck disable=SC2034  # read through ${!var}
WEEK_NAME_2="Text — grep, sed, awk and the sorting toolkit"
# shellcheck disable=SC2034  # read through ${!var}
WEEK_NAME_3="Scripts and the system — functions, options, processes, permissions"
# shellcheck disable=SC2034  # read through ${!var}
WEEK_NAME_4="Automation — tar, rsync, snapshots, verification, scheduling"
# shellcheck disable=SC2034  # read through ${!var}
WEEK_NAME_5="Cool-down — review and graduation"

is_boss() { case "$1" in 7|14|21|28) return 0;; *) return 1;; esac; }
boss_name() { local v="BOSS_NAME_$1"; printf '%s' "${!v:-}"; }
week_name() { local v="WEEK_NAME_$1"; printf '%s' "${!v:-}"; }

# day_num <spec> → "7" for any of: 7, 07, day7, day07, boss1 (boss N = day 7N)
day_num() {
    local s="${1,,}" n
    case "$s" in
        boss[1-4]) n=$(( ${s#boss} * 7 )) ;;
        day*)      n="${s#day}" ;;
        *)         n="$s" ;;
    esac
    [[ "$n" =~ ^[0-9]+$ ]] || return 1
    n=$((10#$n))
    (( n >= 1 && n <= 30 )) || return 1
    printf '%d' "$n"
}
day_id() { printf 'day%02d' "$1"; }          # 7 → day07
drill_file() { printf '%s/drills/%s.sh' "$WORKOUT_LIB" "$(day_id "$1")"; }
drill_dir() { printf '%s/%s' "$WORKOUT_HOME" "$(day_id "$1")"; }

# ── assertions ────────────────────────────────────────────────────────────────
_OK=0; _BAD=0; _UNKNOWN=0
_BAD_LINES=(); _UNKNOWN_LINES=()
ok()      { _OK=$((_OK+1));           printf '   [ok]  %s\n' "$*"; }
bad()     { _BAD=$((_BAD+1));         printf '   [BAD] %s\n' "$*"; _BAD_LINES+=("$*"); }
unknown() { _UNKNOWN=$((_UNKNOWN+1)); printf '   [???] UNKNOWN: %s\n' "$*"; _UNKNOWN_LINES+=("$*"); }

# expect_file <path> [what]         — a regular file exists
expect_file() {
    local what="${2:-${1#"$D"/}}"
    if [[ -f "$1" ]]; then ok "$what exists"; else bad "$what is missing (expected a file at ${1#"$D"/})"; fi
}
expect_dir() {
    local what="${2:-${1#"$D"/}}"
    if [[ -d "$1" ]]; then ok "$what exists"; else bad "$what is missing (expected a directory at ${1#"$D"/})"; fi
}
expect_no_path() {
    local what="${2:-${1#"$D"/}}"
    if [[ ! -e "$1" && ! -L "$1" ]]; then ok "$what is gone"; else bad "$what still exists (it should have been removed)"; fi
}
expect_executable() {
    local what="${2:-${1#"$D"/}}"
    if [[ -x "$1" ]]; then ok "$what is executable"
    elif [[ -f "$1" ]]; then bad "$what exists but is not executable (chmod +x it)"
    else bad "$what is missing"; fi
}
# expect_eq <what> <got> <want>
expect_eq() {
    if [[ "$2" == "$3" ]]; then ok "$1 = $(_q "$3")"
    else bad "$1: expected $(_q "$3"), got $(_q "$2")"; fi
}
# expect_match <what> <got> <ERE>
expect_match() {
    if [[ "$2" =~ $3 ]]; then ok "$1 matches /$3/"
    else bad "$1: expected to match /$3/, got $(_q "$2")"; fi
}
# expect_content <file> <expected-text> [what]   — exact, whole-file comparison
expect_content() {
    local f="$1" want="$2" what="${3:-${1#"$D"/}}" got
    if [[ ! -f "$f" ]]; then bad "$what is missing"; return; fi
    got="$(cat "$f"; printf x)"; got="${got%x}"
    if [[ "$got" == "$want" ]]; then ok "$what has exactly the expected content"
    else
        bad "$what differs from the expected content"
        diff <(printf '%s' "$want") <(printf '%s' "$got") | sed 's/^/          /' | head -20
        printf '          (< expected   > yours)\n'
    fi
}
# expect_lines <file> <expected-text> [what]  — like expect_content but ignores trailing newline count
expect_lines() {
    local f="$1" want="$2" what="${3:-${1#"$D"/}}" got
    if [[ ! -f "$f" ]]; then bad "$what is missing"; return; fi
    got="$(cat "$f")"; want="$(printf '%s' "$want")"
    if [[ "$got" == "$want" ]]; then ok "$what has exactly the expected lines"
    else
        bad "$what differs from the expected lines"
        diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/          /' | head -20
        printf '          (< expected   > yours)\n'
        # the same lines in a different order is almost always locale collation: a UTF-8
        # locale sorts "a A b B .x", C sorts ".x A B a b" — and the drills specify BYTE order
        if [[ "$(sort <<<"$got")" == "$(sort <<<"$want")" ]]; then
            printf '          (same lines, different ORDER: your shell collates by locale (LANG=%s); these drills\n' "${LANG:-unset}"
            printf '           specify BYTE order — write `LC_ALL=C sort`, or `export LC_ALL=C` for the session)\n'
        fi
    fi
}
# expect_grep <file> <ERE> [what]
expect_grep() {
    local what="${3:-${1#"$D"/}}"
    if [[ ! -f "$1" ]]; then bad "$what is missing"; return; fi
    if grep -Eq -- "$2" "$1"; then ok "$what contains /$2/"; else bad "$what does not contain /$2/"; fi
}
expect_no_grep() {
    local what="${3:-${1#"$D"/}}"
    if [[ ! -f "$1" ]]; then bad "$what is missing"; return; fi
    if grep -Eq -- "$2" "$1"; then bad "$what still contains /$2/ (it should not)"; else ok "$what contains no /$2/"; fi
}
# expect_mode <path> <octal>   e.g. expect_mode "$D/x" 640
expect_mode() {
    local got; got="$(stat -c '%a' "$1" 2>/dev/null)" || { bad "${1#"$D"/} is missing"; return; }
    [[ "$got" == "$2" ]] && ok "${1#"$D"/} has mode $2" || bad "${1#"$D"/}: expected mode $2, got ${got:-?}"
}
# expect_rc <what> <want-rc> <cmd...>   — runs the command (output discarded)
expect_rc() {
    local what="$1" want="$2"; shift 2
    local rc=0; "$@" >/dev/null 2>&1 || rc=$?
    if (( rc == want )); then ok "$what exits $want"; else bad "$what: expected exit status $want, got $rc"; fi
}
# expect_same_tree <dirA> <dirB> [what]  — identical names + contents (diff -r)
expect_same_tree() {
    local what="${3:-${2#"$D"/}}" out
    if [[ ! -d "$2" ]]; then bad "$what is missing"; return; fi
    if out="$(diff -r "$1" "$2" 2>&1)"; then ok "$what matches the expected tree exactly"
    else bad "$what differs from the expected tree:"; printf '%s\n' "$out" | sed 's/^/          /' | head -12; fi
}
_q() { printf '%q' "$1"; }

# verdict <day> — the one line a check ends on. Returns 0 only on a clean pass.
verdict() {
    local n="$1" title="$2"
    printf '\n'
    if (( _BAD == 0 && _UNKNOWN == 0 )); then
        printf 'PASS: day %02d — %s (%d/%d assertions hold)\n' "$n" "$title" "$_OK" "$_OK"
        return 0
    fi
    local total=$((_OK + _BAD + _UNKNOWN))
    if (( _BAD > 0 )); then
        printf 'FAIL: day %02d — %s (%d of %d assertions failed' "$n" "$title" "$_BAD" "$total"
        (( _UNKNOWN > 0 )) && printf ', %d UNKNOWN' "$_UNKNOWN"
        printf ')\n'
    else
        printf 'UNKNOWN: day %02d — %s (%d/%d hold, but %d could not be verified on this machine — see the [???] lines)\n' \
            "$n" "$title" "$_OK" "$total" "$_UNKNOWN"
    fi
    return 1
}

# ── fixture helpers ───────────────────────────────────────────────────────────
# safe_reset <dir> — empty and recreate a drill directory. Refuses anything that is not
# a dayNN directory directly under $WORKOUT_HOME, so no misconfiguration can turn this
# into `rm -rf` of something that matters.
safe_reset() {
    local d="$1"
    case "$d" in
        "$WORKOUT_HOME"/day[0-3][0-9]) ;;
        *) printf 'refusing to reset %q: not a dayNN directory under %q\n' "$d" "$WORKOUT_HOME" >&2; return 1 ;;
    esac
    [[ "$WORKOUT_HOME" != / && "$WORKOUT_HOME" != "$HOME" && -n "$WORKOUT_HOME" ]] || { printf 'refusing: WORKOUT_HOME=%q\n' "$WORKOUT_HOME" >&2; return 1; }
    rm -rf -- "$d" && mkdir -p -- "$d"
}
# mkfile <path> <content…>  — create a file (and its parents) with the given text + newline
mkfile() { local p="$1"; shift; mkdir -p -- "$(dirname -- "$p")"; printf '%s\n' "$@" > "$p"; }
# at <path> <YYYY-MM-DD HH:MM> — pin an mtime so size/age-based drills are deterministic
at() { touch -d "$2" -- "$1"; }
# bytes <path> <n> — a file of exactly n bytes (NUL-free, so text tools behave)
bytes() { mkdir -p -- "$(dirname -- "$1")"; head -c "$2" /dev/zero | tr '\0' 'x' > "$1"; }
# have <cmd>…
have() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || return 1; done; }
# run_in <dir> <cmd…> — run with cwd=dir, in a subshell (so a `die`/`exit` is contained)
run_in() { local d="$1"; shift; ( cd -- "$d" && "$@" ); }
