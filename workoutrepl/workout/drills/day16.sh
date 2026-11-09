# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day16 — getopts and CLI hygiene
DRILL_TITLE="getopts and CLI hygiene — options, --help on stdout, EX_USAGE, and the -- separator"
DRILL_WEEK=3
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
Write tool.sh, a small command-line tool with correct manners:

  tool.sh [-n COUNT] [-u] [-o FILE] [--] WORD...
    prints each WORD on its own line, COUNT times (default 1); -u upper-cases;
    -o FILE writes the output to FILE instead of stdout.

  Manners the checker enforces:
    • `tool.sh -h` and `tool.sh --help` print a usage text to STDOUT, write nothing to
      stderr, and exit 0.
    • an unknown option (`-z`) prints an error AND the usage to STDERR and exits 64
      (EX_USAGE from sysexits.h); a missing option argument (`-n` with nothing after
      it) does the same.
    • `-n` must be a positive integer; `-n abc` exits 64 with a message on stderr.
    • no WORD at all is a usage error (64).
    • `tool.sh -- -u` prints `-u` (after `--`, a dash-word is a word, not an option).
    • options may come in any order and may be bundled: `-un 2 hi` == `-u -n 2 hi`.

Why: getopts is small and worth knowing cold — it handles bundling, `--`, and
OPTARG/OPTIND for you. The manners are what separate a script from a tool: help on
stdout so `tool --help | less` works, errors on stderr so they cannot be captured as
data, and a distinct exit status so a caller can tell "you called me wrong" from
"I failed".
EOF
}

hint() {
    cat <<'EOF'
while getopts ':n:uo:h' opt; do case $opt in
    n) count=$OPTARG ;; u) upper=1 ;; o) out=$OPTARG ;; h) usage; exit 0 ;;
    :) echo "missing argument for -$OPTARG" >&2; usage >&2; exit 64 ;;
    \?) echo "unknown option -$OPTARG" >&2; usage >&2; exit 64 ;;
esac; done; shift $((OPTIND-1))
A leading `:` in the optstring puts getopts in silent mode so YOU print the errors.
Check `--help` BEFORE getopts (getopts sees it as `-`, `-`, `h`…).
EOF
}

setup() { :; }

check() {
    expect_executable tool.sh
    [[ -x tool.sh ]] || return
    local out err rc
    out="$(./tool.sh hello world 2>/dev/null)"; expect_eq "tool.sh hello world" "$out" $'hello\nworld'
    out="$(./tool.sh -n 2 -u hi 2>/dev/null)"; expect_eq "tool.sh -n 2 -u hi" "$out" $'HI\nHI'
    out="$(./tool.sh -un 2 hi 2>/dev/null)";   expect_eq "tool.sh -un 2 hi (bundled)" "$out" $'HI\nHI'
    out="$(./tool.sh hi -u 2>/dev/null)";      expect_eq "tool.sh hi -u (option after word — GNU-style permutation is NOT expected; getopts stops at the first word)" "$out" $'hi\n-u'
    out="$(./tool.sh -- -u 2>/dev/null)";      expect_eq "tool.sh -- -u" "$out" "-u"
    rm -f out.txt; ./tool.sh -o out.txt -n 3 x >/dev/null 2>&1
    expect_lines out.txt $'x\nx\nx' "out.txt via -o"
    out="$(./tool.sh --help 2>/dev/null)"; err="$(./tool.sh --help 2>&1 >/dev/null)"; ./tool.sh --help >/dev/null 2>&1; rc=$?
    [[ -n "$out" ]] && ok "--help prints usage on stdout" || bad "--help printed nothing on stdout"
    [[ -z "$err" ]] && ok "--help writes nothing to stderr" || bad "--help wrote to stderr: $(head -1 <<<"$err")"
    expect_eq "--help exit status" "$rc" 0
    out="$(./tool.sh -h 2>/dev/null)"; [[ -n "$out" ]] && ok "-h prints usage on stdout" || bad "-h printed nothing on stdout"
    err="$(./tool.sh -z hi 2>&1 >/dev/null)"; ./tool.sh -z hi >/dev/null 2>&1; rc=$?
    expect_eq "unknown option -z exits EX_USAGE" "$rc" 64
    [[ -n "$err" ]] && ok "unknown option reports on stderr" || bad "unknown option printed nothing on stderr"
    ./tool.sh -n >/dev/null 2>&1; rc=$?;      expect_eq "-n with no argument exits 64" "$rc" 64
    ./tool.sh -n abc hi >/dev/null 2>&1; rc=$?; expect_eq "-n abc exits 64" "$rc" 64
    ./tool.sh -n 0 hi >/dev/null 2>&1; rc=$?;   expect_eq "-n 0 exits 64 (positive means >= 1)" "$rc" 64
    ./tool.sh >/dev/null 2>&1; rc=$?;           expect_eq "no WORD exits 64" "$rc" 64
    out="$(./tool.sh -z hi 2>/dev/null)"; [[ -z "$out" ]] && ok "errors do not leak onto stdout" || bad "an error case printed to stdout: $(head -1 <<<"$out")"
}

solve() {
    cat > tool.sh <<'EOF'
#!/usr/bin/env bash
# tool.sh [-n COUNT] [-u] [-o FILE] [--] WORD...
set -uo pipefail
usage() {
    cat <<'USAGE'
usage: tool.sh [-n COUNT] [-u] [-o FILE] [--] WORD...
  -n COUNT   print each word COUNT times (default 1)
  -u         upper-case the words
  -o FILE    write to FILE instead of stdout
  -h, --help this text
USAGE
}
[[ ${1-} == --help ]] && { usage; exit 0; }
count=1 upper=0 out=
while getopts ':n:uo:h' opt; do
    case $opt in
        n) count=$OPTARG ;;
        u) upper=1 ;;
        o) out=$OPTARG ;;
        h) usage; exit 0 ;;
        :)  printf 'tool.sh: option -%s needs an argument\n' "$OPTARG" >&2; usage >&2; exit 64 ;;
        \?) printf 'tool.sh: unknown option -%s\n' "$OPTARG" >&2; usage >&2; exit 64 ;;
    esac
done
shift $((OPTIND - 1))
[[ $count =~ ^[1-9][0-9]*$ ]] || { printf 'tool.sh: -n needs a positive integer, got %q\n' "$count" >&2; exit 64; }
(( $# )) || { printf 'tool.sh: at least one WORD is required\n' >&2; usage >&2; exit 64; }
emit() {
    local w i
    for w in "$@"; do
        (( upper )) && w=${w^^}
        for (( i = 0; i < count; i++ )); do printf '%s\n' "$w"; done
    done
}
if [[ -n $out ]]; then emit "$@" > "$out"; else emit "$@"; fi
EOF
    chmod +x tool.sh
}
