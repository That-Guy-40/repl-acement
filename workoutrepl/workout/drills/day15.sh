# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day15 — Functions and arrays
DRILL_TITLE="Functions and arrays — locals, return vs output, indexed and associative arrays"
DRILL_WEEK=3
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
Write lib.sh — a file meant to be SOURCED, defining five functions. The checker sources
it into a clean bash and calls them; it also checks that calling them leaks no global
variables (every working variable must be `local`).

  join_by SEP ITEM...     print ITEMs joined by SEP:   join_by , a b c  → a,b,c
                          (SEP may be more than one character; no trailing SEP)
  max N...                print the largest integer argument; with no arguments print
                          nothing and return 1
  trim STR                print STR with leading and trailing whitespace removed
                          (spaces and tabs) — pure parameter expansion, no sed
  contains NEEDLE ITEM... return 0 if NEEDLE equals one of the ITEMs exactly, else 1;
                          print nothing (this is a PREDICATE: its result is its status)
  count_words             read stdin, print `word count` lines for every distinct
                          word (split on whitespace), sorted by word — an associative
                          array (declare -A) and a sort

Conventions the checker enforces: functions return DATA on stdout and STATUS via
return; nothing is printed to stderr on the happy path; `set -u` must not break them.

Why: bash functions are the unit of reuse, and the two idioms people miss are `local`
(without it every helper quietly overwrites its caller's variables) and the split
between "a function that answers a question" (return status) and "a function that
produces a value" (stdout).
EOF
}

hint() {
    cat <<'EOF'
join_by() { local sep=$1; shift; local out=$1; shift; for x in "$@"; do out+="$sep$x"; done; printf '%s\n' "$out"; }
trim: local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}
count_words() { local -A c; local w; while read -ra ws; do for w in "${ws[@]}"; do c[$w]=$(( ${c[$w]:-0} + 1 )); done; done; for w in "${!c[@]}"; do printf '%s %s\n' "$w" "${c[$w]}"; done | sort; }
EOF
}

setup() { mkfile words.txt "the quick brown fox" "jumps over the lazy dog" "the end"; }

_call() {   # _call <bash snippet> — run in a clean bash with lib.sh sourced, under set -u
    bash --norc --noprofile -c 'set -u; . ./lib.sh || exit 99; '"$1" 2>&1
}
check() {
    expect_file lib.sh
    [[ -f lib.sh ]] || return
    local got rc
    bash -n lib.sh 2>/dev/null && ok "lib.sh parses (bash -n)" || { bad "lib.sh has a syntax error"; return; }
    got="$(_call 'join_by , a b c')";            expect_eq "join_by , a b c" "$got" "a,b,c"
    got="$(_call 'join_by " -- " one two')";     expect_eq "join_by ' -- ' one two" "$got" "one -- two"
    got="$(_call 'join_by , solo')";             expect_eq "join_by , solo" "$got" "solo"
    got="$(_call 'max 3 17 -4 9')";              expect_eq "max 3 17 -4 9" "$got" "17"
    got="$(_call 'max; echo "rc=$?"')";          expect_eq "max (no args) prints nothing, returns 1" "$got" "rc=1"
    got="$(_call 'trim "$(printf "  \t hello world \t ")"')"; expect_eq "trim" "$got" "hello world"
    got="$(_call 'contains b a b c; echo "rc=$?"')";  expect_eq "contains b a b c (status only)" "$got" "rc=0"
    got="$(_call 'contains z a b c; echo "rc=$?"')";  expect_eq "contains z a b c" "$got" "rc=1"
    got="$(_call 'contains "a b" "a b" c; echo "rc=$?"')"; expect_eq "contains with a spaced needle" "$got" "rc=0"
    got="$(_call 'count_words < words.txt')"
    expect_eq "count_words" "$got" $'brown 1\ndog 1\nend 1\nfox 1\njumps 1\nlazy 1\nover 1\nquick 1\nthe 3'
    # no global leakage: the set of variables after the calls must equal the set before
    got="$(_call 'before=$(compgen -v | sort); join_by , a b >/dev/null; max 1 2 >/dev/null; trim " x " >/dev/null; contains a a; count_words </dev/null >/dev/null; after=$(compgen -v | sort); diff <(echo "$before") <(echo "$after") | grep "^>" | grep -vE "^> (before|after)$"')"
    [[ -z "$got" ]] && ok "no global variables leak out of the functions (all locals)" || bad "these globals appeared after calling your functions — declare them local: $(tr '\n' ' ' <<<"$got")"
}

solve() {
    cat > lib.sh <<'EOF'
# lib.sh — source me
join_by() {                       # join_by SEP ITEM...
    local sep=$1; shift
    local out=${1-}; shift || true
    local x
    for x in "$@"; do out+="$sep$x"; done
    printf '%s\n' "$out"
}
max() {                           # max N...  → largest; no args → status 1
    (( $# )) || return 1
    local m=$1 x
    for x in "$@"; do (( x > m )) && m=$x; done
    printf '%s\n' "$m"
}
trim() {                          # trim STR → STR without leading/trailing blanks
    local s=$1
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s\n' "$s"
}
contains() {                      # contains NEEDLE ITEM... → status only
    local needle=$1 x; shift
    for x in "$@"; do [[ $x == "$needle" ]] && return 0; done
    return 1
}
count_words() {                   # stdin → "word count" lines, sorted by word
    local -A c
    local -a ws
    local w
    while read -ra ws; do
        for w in "${ws[@]}"; do c[$w]=$(( ${c[$w]:-0} + 1 )); done
    done
    for w in "${!c[@]}"; do printf '%s %s\n' "$w" "${c[$w]}"; done | LC_ALL=C sort
}
EOF
}
