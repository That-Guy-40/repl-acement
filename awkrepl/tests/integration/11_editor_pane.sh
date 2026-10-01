#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
##
##  integration/11_editor_pane.sh - the editor pane's wrapper runs $EDITOR
##  through the shell (so flags such as 'code -w' work, as with git), then
##  removes the REPL's temp files. Run outside tmux: with no $TMUX_PANE the
##  wrapper must not try to close any window.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$(cd "$TESTS_DIR/../.." && pwd)/awkrepl"
source "$TESTS_DIR/../helpers.sh"
source "$TOOL"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work"                     # the REPL's temp files land here

# a fake editor that records the arguments it was given
printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/editor-args"\n' "$work" > "$work/fakeed"
chmod +x "$work/fakeed"

replfile="$work/my repl file"             # a space, to check the quoting
: > "$replfile"
EDITOR="$work/fakeed --wait" _awkrepl_setup "$replfile"

env -u TMUX -u TMUX_PANE bash "$REPL_EDITPANE"; rc=$?
assert_equals "the wrapper exits 0 when the editor does" "0" "$rc"
assert_equals "\$EDITOR's flag and the file reach the editor" \
    "--wait
$replfile" "$(cat "$work/editor-args" 2>/dev/null)"

left=()
for v in REPL_SRC REPL_DATA REPL_ARGS REPL_RUNNER REPL_FORMATTER REPL_CLEANUP REPL_EDITPANE REPL_HELPERS; do
    [[ -e ${!v} ]] && left+=("$v")
done
assert_equals "after the editor exits, every temp file is removed" "" "${left[*]}"

summary
