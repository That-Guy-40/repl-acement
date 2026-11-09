#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
##
##  integration/02_editor_pane.sh - the editor pane's wrapper runs $EDITOR
##  through the shell (so flags such as 'code -w' work, as with git), then
##  removes the REPL's temp files. Run outside tmux: with no $TMUX_PANE the
##  wrapper must not try to close any window. Same contract as the other
##  six REPLs' wrappers (perlrepl/tests/integration/09_editor_pane.sh).
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"
source "$DIR/workoutrepl"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work"                     # the REPL's temp files land here

# a fake editor that records the arguments it was given
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/editor-args"\n' "$work" > "$work/fakeed"
chmod +x "$work/fakeed"

replfile="$work/my repl file"             # a space, to check the quoting
: > "$replfile"
EDITOR="$work/fakeed --wait" _wr_setup "$replfile"

n=$(find "$work" -maxdepth 1 -name 'workoutrepl-*' | wc -l)
assert_equals "setup creates the REPL's eight scratch files under TMPDIR" "8" "$n"
assert_file_contains "the runner script embeds the trainer path" "bin/workout" "$REPL_RUNNER"
assert_file_contains "the checker script calls _wr_check"        "_wr_check"   "$REPL_CHECKER"

env -u TMUX -u TMUX_PANE bash "$REPL_EDITPANE"; rc=$?
assert_equals "the wrapper exits 0 when the editor does" "0" "$rc"
assert_equals "\$EDITOR's flag and the file reach the editor" \
    "--wait
$replfile" "$(cat "$work/editor-args" 2>/dev/null)"

left=()
for v in REPL_BODY REPL_DATA REPL_HDRS REPL_STAMP REPL_RUNNER REPL_CHECKER REPL_CLEANUP REPL_EDITPANE; do
    [[ -e ${!v} ]] && left+=("$v")
done
assert_equals "after the editor exits, every temp file is removed" "" "${left[*]}"
[[ -e "$REPL_STAMP.armed" ]] && fail "the .armed marker survived cleanup" || pass "the stamp's .armed marker is removed too"

# a trainer that is not there must be refused at setup, before any pane opens
out=$(WORKOUT_LIB="$work/nowhere" bash -c 'source "$1"; _wr_setup "$2"' _ "$DIR/workoutrepl" "$replfile" 2>&1); rc=$?
assert_equals "setup fails when the trainer is missing" "1" "$rc"
if [[ $out == *"trainer not found"* ]]; then
    pass "…and says so, naming WORKOUT_LIB"
else
    fail "…without saying the trainer is missing" "$out"
fi

summary
