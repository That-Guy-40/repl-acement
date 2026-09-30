#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  integration/09_args_quoting.sh - _repl_parse_args honors shell quotes
##  but never globs or expands (the #ARGS parsing shared by every REPL).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$(cd "$TESTS_DIR/../.." && pwd)/awkrepl"
source "$TESTS_DIR/../helpers.sh"
source "$TOOL"

# parse ARG-LINE as if it were the #ARGS content (a trailing newline is added
# here); fills the global array PARSED
parse_into() {
    local content=$1 f; f=$(mktemp)
    printf '%s\n' "$content" > "$f"
    PARSED=()
    while IFS= read -r -d '' a; do PARSED+=("$a"); done < <(_repl_parse_args "$f")
    rm -f "$f"
}

# run in a scratch dir that actually contains files matching the glob, so a
# literal '*' surviving proves no globbing happened
work=$(mktemp -d)
cd "$work" || exit 1
touch aa.tmp bb.tmp
trap 'cd /; rm -rf "$work"' EXIT

# --- a double-quoted value keeps its spaces as ONE token ---
parse_into '-v "greeting=hello world"'
assert_equals "double-quoted value stays one token"   "2" "${#PARSED[@]}"
assert_equals "double-quoted value preserves spaces"  "greeting=hello world" "${PARSED[1]}"

# --- single quotes work too ---
parse_into "-v 'x=a b c'"
assert_equals "single-quoted value stays one token"   "2" "${#PARSED[@]}"
assert_equals "single-quoted value preserves spaces"  "x=a b c" "${PARSED[1]}"

# --- unquoted whitespace splits into separate tokens ---
parse_into '-v x=a b'
assert_equals "unquoted whitespace splits"            "3" "${#PARSED[@]}"

# --- a glob metacharacter is passed through literally (no expansion) ---
parse_into '-n *.tmp'
assert_equals "glob token count unchanged"            "2" "${#PARSED[@]}"
assert_equals "glob char NOT expanded"                "*.tmp" "${PARSED[1]}"

# --- empty / whitespace-only yields NO tokens (no spurious empty arg) ---
parse_into '     '
assert_equals "whitespace-only yields no tokens"      "0" "${#PARSED[@]}"
parse_into ''
assert_equals "empty file yields no tokens"           "0" "${#PARSED[@]}"

summary
