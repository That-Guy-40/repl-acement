# AWK REPL: Tmux Integration and Event-Driven Architecture

## Overview

awkrepl creates a **three-pane tmux window** (in a new tmux session, or as a new window in the current session if you are already inside tmux) that implements a reactive, event-driven interactive development environment. This document explains how tmux and entr work together to create the user-facing interface.

---

## Tmux Session Layout

### Pane Structure

```
┌─────────────────────────────────────────┐
│   PANE 0 (top, full width, ~50% height) │
│   ┌─────────────────────────────────┐   │
│   │  $EDITOR ~/.repl.awk            │   │
│   │  ┌─────────────────────────┐    │   │
│   │  │  Text editor with       │    │   │
│   │  │  ~/.repl.awk open       │    │   │
│   │  │  (nano, vim, jove, etc.)│    │   │
│   │  └─────────────────────────┘    │   │
│   └─────────────────────────────────┘   │
├───────────────────┬─────────────────────┤
│   PANE 1          │   PANE 2            │
│   (bottom-left)   │   (bottom-right)    │
│   ┌─────────────┐ │   ┌───────────────┐ │
│   │ entr        │ │   │ entr          │ │
│   │ ~/.repl.awk │ │   │ $src (temp)   │ │
│   │ → $runner   │ │   │ → $formatter  │ │
│   │ gawk output │ │   │ pretty-print  │ │
│   └─────────────┘ │   └───────────────┘ │
└───────────────────┴─────────────────────┘
```

**Pane 0 (Top)**: full width, ~50% height - Your text editor
**Pane 1 (Bottom-left)**: ~50% width - AWK execution output
**Pane 2 (Bottom-right)**: ~50% width - Pretty-printed AWK code

(Pane numbers assume tmux's default `pane-base-index` of 0; verified with tmux 3.4.)

---

## Tmux Command Breakdown

### Command Structure (in `awkrepl()`)

```bash
local close='; tmux kill-window -t "$TMUX_PANE"'
local session="awkrepl-$$"                                     # Step A
local -a launch=(new-session -s "$session")
if [[ -n "${TMUX:-}" ]]; then launch=(new-window); fi
tmux "${launch[@]}" -n 'awkrepl'                               \
  "$REPL_Q_EDITPANE" \;                                        \   # Step B
  split-window    -c "$PWD"                                    \   # Step C
    "echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER$close" \;  \   # Step D
  split-window -h -c "$PWD"                                    \   # Step E
    "echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER$close" \;    \   # Step F
  select-pane -t 1 \;                                          \   # Step G
  select-pane -t 2 \;                                          \   # Step H
  select-pane -t 0                                                 # Step I
```

(Step comments added for this document; they are not in the script.)

All temp-file paths are created by `_awkrepl_setup` (see below) with
`mktemp "${TMPDIR:-/tmp}/awkrepl-<kind>-XXXXXX"` and are absolute paths. The
`REPL_Q_*` variables hold `printf '%q'`-quoted versions of those paths so they
survive being embedded in the tmux command strings and generated scripts.

### Step-by-Step Explanation

#### Step A: Create Session or Window
```bash
local session="awkrepl-$$"
local -a launch=(new-session -s "$session")
if [[ -n "${TMUX:-}" ]]; then launch=(new-window); fi
tmux "${launch[@]}" -n 'awkrepl'
```
- If **outside tmux**: `tmux new-session -s awkrepl-<pid>` creates a new session with a known name, whose first window is named `awkrepl` (`-n` names the window). This call returns when the session ends **or when the client detaches**; the name lets the cleanup backstop tell the two apart.
- If **inside tmux** (`$TMUX` is set): `tmux new-window` creates a new window named `awkrepl` in the current session and returns immediately.

#### Step B: Create Pane 0 (Editor)
```bash
"$REPL_Q_EDITPANE"
```
- First pane (pane 0) runs the generated `$editpane` wrapper script (`${TMPDIR:-/tmp}/awkrepl-edit-XXXXXX`), which opens the editor with `~/.repl.awk` (created with `touch` if missing)
- Uses `$EDITOR` or defaults to `nano` (fixed when the wrapper is generated)
- When the editor exits, the wrapper removes the temp files and closes this window (see Cleanup Mechanism)
- This pane initially fills the window; after Step C it occupies the **top ~50%**

#### Step C: Split Top/Bottom (Pane 1)
```bash
split-window -c "$PWD" "echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER$close"
```
- Splits pane 0 into top and bottom halves (`split-window` defaults to `-v`)
- Creates pane 1 below at ~50% height; pane 1 becomes the active pane
- `-c "$PWD"` sets working directory

#### Step D: entr #1 - Runner (Pane 1)
```bash
echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER; tmux kill-window -t "$TMUX_PANE"
```
- **Watches**: `$replfile` = `$HOME/.repl.awk`
- **Runs once at startup**, then again on each change:
  - Clear screen (`-c`)
  - Execute the `$runner` script (by absolute path)
- `$runner` executes: `_awkrepl_divide` + `_repl_parse_args` + `gawk`
- If `entr` exits, `tmux kill-window -t "$TMUX_PANE"` closes this REPL's window (`$TMUX_PANE` is expanded by the pane's shell, so it names this pane)

#### Step E: Split Left/Right (Pane 2)
```bash
split-window -h -c "$PWD" "echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER$close"
```
- Splits the active pane (pane 1) side by side (`-h` flag)
- Creates pane 2 to the right at ~50% width

#### Step F: entr #2 - Formatter (Pane 2)
```bash
echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER; tmux kill-window -t "$TMUX_PANE"
```
- **Watches**: `$src` = temp file (`${TMPDIR:-/tmp}/awkrepl-src-XXXXXX`)
- **Runs once at startup**, then again on each change:
  - Clear screen (`-c`)
  - Execute the `$formatter` script (by absolute path)
- `$formatter` executes: `sleep 1`, then `_awkrepl_pretty_print`
- If `entr` exits, this REPL's window is closed, as in Step D

#### Steps G-I: Pane Selection
```bash
select-pane -t 1 \;  # Select pane 1 (runner)
select-pane -t 2 \;  # Select pane 2 (formatter)
select-pane -t 0     # Select pane 0 (editor) ← focus ends here
```
- The last command leaves focus on the editor (pane 0), so the user can start typing immediately after awkrepl starts
- Side effect of the sequence: pane 2 becomes tmux's "last pane"

#### No Cleanup Hooks

awkrepl sets no tmux hooks. Earlier versions used `set-hook 'pane-exited[0]'`
/ `'pane-exited[1]'`, but tmux resolves those against the session's current
window whichever pane exited, so when awkrepl was nested in your own tmux
session any pane exiting anywhere ran its cleanup and killed a window. Each
pane now closes its own window instead, via `$TMUX_PANE` (see Cleanup
Mechanism).

---

## entr: Event-Driven File Watcher

### How entr Works

entr runs a command when any of the files whose paths it reads on stdin change:

```bash
echo file | entr command
```

1. **`echo file`** - Sends the file path to entr's stdin
2. **`entr -c command`** - Run `command` once, then again (after clearing the screen, `-c`) each time the file changes

### entr's Event Loop

```
entr → inotify/kqueue → wait for file event → execute command → loop
```

**Linux**: Uses `inotify`
**BSD/macOS**: Uses `kqueue`

### Two entr Processes in awkrepl

#### entr #1: Runner (Pane 1)

```bash
echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER
```

| Aspect | Detail |
|------|------|
| **File watched** | `$HOME/.repl.awk` (user's AWK source) |
| **Trigger** | Startup, then file write/save event |
| **Command executed** | `$runner` script |
| **Purpose** | Execute AWK and show output |

**`$runner` script (abridged; paths are the actual quoted temp paths):**
```bash
#!/usr/bin/env bash
set -uo pipefail
# (embeds _sed_in_place, _awkrepl_parses, _awkrepl_looks_like_statement,
#  _awkrepl_divide, _repl_parse_args via declare -f)
_awkrepl_divide ~/.repl.awk $src $data $args
_gawk_args=()
while IFS= read -r -d '' _a; do _gawk_args+=( "$_a" ); done < <(_repl_parse_args $args)
echo "# work dir: $PWD"
echo "# command:  gawk ${_gawk_args[*]} -f $helpers -f $src $data"
gawk "${_gawk_args[@]}" -f $helpers -f $src $data   # AWK execution
```

`_repl_parse_args` uses `xargs` to split the `#ARGS` text into NUL-separated
tokens, honoring shell quotes but performing no globbing or expansion. On an
unmatched quote (e.g. `it's`) it prints `warning: #ARGS has an unmatched quote;
splitting it on whitespace instead` to stderr (shown in pane 1) and splits the
line on whitespace, keeping the quote characters as typed. The two
`echo` header lines are wrapped in `tput dim` / `tput sgr0` (evaluated when
the script is generated, so the dim attribute is baked into `$runner`).

#### entr #2: Formatter (Pane 2)

```bash
echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER
```

| Aspect | Detail |
|------|------|
| **File watched** | `$src` (temp file rewritten by the runner) |
| **Trigger** | Startup, then each time the runner rewrites `$src` |
| **Command executed** | `$formatter` script |
| **Purpose** | Pretty-print AWK with syntax highlighting |

**`$formatter` script:**
```bash
#!/usr/bin/env bash
set -uo pipefail
# (embeds _awkrepl_pretty_print via declare -f)
sleep 1
_awkrepl_pretty_print $src
```

### Why `sleep 1` in Formatter?

The script does not document the reason, but the `sleep 1` gives the runner
time to finish rewriting `$src`. `_awkrepl_divide` writes `$src` up to four
times in a row: `sed … > $src` (the split at `#DATA`), two `_sed_in_place`
passes (`sed -i`, each of which replaces the file; a third `_sed_in_place`
call edits `$data`, not `$src`), and, when the program is auto-wrapped, a
final `printf … > $src`. Each of those writes can fire entr #2:

```
entr #1 triggers $runner              entr #2 triggers $formatter
        │                                      │
        ▼                                      ▼
  _awkrepl_divide                           sleep 1
        │                                      │
        ▼                                      ▼
  rewrite $src (several passes)           read $src
        │                                      │
        └───────► incomplete read? ◄───────────┘
```

Without the sleep, the formatter could read `$src` while the runner is still rewriting it.

---

## Event Flow Diagram

```
┌──────────────────────────────────────────────────────┐
│ USER: Saves ~/.repl.awk                              │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│ entr #1 (pane 1):                                    │
│   watches ~/.repl.awk                                │
│   ┌─ event: file modified ─────────┐                 │
│   │  → clear screen (entr -c)      │                 │
│   │  → execute $runner             │                 │
│   └────────────────────────────────┘                 │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│ $runner executes:                                    │
│   _awkrepl_divide ~/.repl.awk $src $data $args       │
│     ├─ Split at the first #DATA → $src / $data       │
│     ├─ Extract #ARGS line(s) from $src → $args       │
│     ├─ Clean source (remove headers/comments)        │
│     ├─ Auto-wrap in { } or END { } if it parses only │
│     │  wrapped, or both ways and looks like a        │
│     │  statement (checked with gawk)                 │
│     └─ Rewrite $src (cleaned)  ────────┐             │
│                                        │             │
│   _repl_parse_args $args → array       │             │
│   gawk ARGS... -f $helpers -f $src $data             │
│     └─> output in pane 1               │             │
│                                        │             │
│   (side effect: $src rewritten) ───────┘             │
└──────────────────────────────────────────────────────┘
                    │
                    ▼ (file change)
┌──────────────────────────────────────────────────────┐
│ entr #2 (pane 2):                                    │
│   watches $src                                       │
│   ┌─ event: file modified ─────────┐                 │
│   │  → clear screen (entr -c)      │                 │
│   │  → execute $formatter          │                 │
│   └────────────────────────────────┘                 │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│ $formatter executes:                                 │
│   sleep 1                                            │
│   _awkrepl_pretty_print $src                         │
│     ├─ gawk --pretty-print=- -f $src                 │
│     ├─ pipe through bat/batcat (if available)        │
│     └─ on parse error: print ERROR + raw source      │
│   └─> formatted code in pane 2                       │
└──────────────────────────────────────────────────────┘
```

---

## File Change Triggers

### Triggered Files

| entr instance | File watched | File type | Created by | Trigger |
|---|---|---|---|-------|
| **entr #1** | `$HOME/.repl.awk` | User's AWK source | User (in editor); `touch`ed by `awkrepl()` if missing | File save in editor |
| **entr #2** | `${TMPDIR:-/tmp}/awkrepl-src-XXXXXX` | Cleaned source extract | `mktemp` in `_awkrepl_setup`; rewritten by `_awkrepl_divide()` in `$runner` | Runner rewrites temp file |

### Trigger Chain

1. User saves `~/.repl.awk` in editor
2. entr #1 detects change
3. `$runner` executes and rewrites `$src`
4. entr #2 detects change in `$src`
5. `$formatter` executes

**Result**: One save-event triggers **both panes** sequentially

---

## The `AWKHELPERS` Library

`AWKHELPERS` is a global string defined at the top of the script. `_awkrepl_setup` writes it to a temp file (`${TMPDIR:-/tmp}/awkrepl-helpers-XXXXXX`):

```bash
AWKHELPERS='# vim: ft=awk
    function printerr(msg) {
        # Print error to stderr
    }
    function printa(a,  name,fs,l,i) {
        # Print numerically-indexed (1-based, contiguous) array
    }
    function printaa(a,  name,fs,l,n,i) {
        # Print associative array
    }
'
```

These helpers are included in every AWK execution via `-f $helpers` (before `-f $src`).

---

## Cleanup Mechanism

### Trigger 1: The Editor Pane's Wrapper (`$editpane`)

Pane 0 runs this generated script rather than the editor itself:
```bash
#!/usr/bin/env bash
_editor=
_done() {
    trap - HUP TERM
    [[ -n "$_editor" ]] && kill "$_editor" 2>/dev/null
    $cleanup                                   # %q-quoted path
    [[ -n "${TMUX_PANE:-}" ]] && tmux kill-window -t "$TMUX_PANE" 2>/dev/null
    exit 0
}
trap _done HUP TERM
trap '' INT QUIT
$EDITOR ~/.repl.awk <&0 &                      # $EDITOR as typed (may carry flags); %q-quoted path
_editor=$!
wait "$_editor"
_editor=
_done
```

`$EDITOR` is run by the shell, as git does, so it may carry flags such as
`code -w`. The editor runs as a child that the wrapper waits on, rather than
in the foreground: bash defers a trap until a foreground child exits, and a
killed window's editor may never exit, so the cleanup would never run. `<&0`
keeps the pane's terminal as the editor's input (a background command would
otherwise get `/dev/null`).

When the editor exits, or the wrapper gets SIGHUP/SIGTERM (e.g. the window is
killed), it stops the editor if it's still running and runs the generated
`$cleanup` script:
```bash
#!/usr/bin/env bash
rm -f $src $data $args $runner $formatter $helpers $editpane $cleanup   # %q-quoted paths
```
and then `tmux kill-window -t "$TMUX_PANE"`, which closes the window that
contains its own pane, so it never touches other windows when awkrepl runs
inside an existing tmux session.

### Trigger 2: An entr Pane Exits

Panes 1 and 2 run `echo … | entr -c …; tmux kill-window -t "$TMUX_PANE"`, so if
either `entr` exits, the REPL's window is closed too; the editor pane's wrapper
then gets SIGHUP and removes the temp files.

### Trigger 3: Backstop in `awkrepl()`

For the rare case the wrapper can't clean up (e.g. its process was SIGKILLed),
`awkrepl()` removes the temp files itself after `tmux new-session` returns,
**only when not nested in tmux** (`$TMUX` unset) **and only once its named
session is gone**. `tmux new-session` also returns when the client merely
detaches (`C-b d`); the detached session still needs its files, so they are
left alone and you can reattach later. When nested, `tmux new-window` returns
immediately while the window is still live, so cleanup is left to the wrapper.

```bash
if [[ -z "${TMUX:-}" ]] && ! tmux has-session -t "=$session" 2>/dev/null; then
    rm -f "$REPL_SRC" "$REPL_DATA" "$REPL_ARGS" "$REPL_RUNNER" \
          "$REPL_FORMATTER" "$REPL_CLEANUP" "$REPL_EDITPANE" "${REPL_HELPERS:-}"
fi
```

---

## Tmux Features Used

| Feature | Purpose in awkrepl |
|---------|-------------------|
| `tmux new-session -s awkrepl-<pid>` | Start a new, named session |
| `tmux new-window` | Create new window (when in tmux) |
| `tmux has-session` | Backstop: check the named session is really gone |
| `-n awkrepl` | Name the window |
| `split-window` | Create top/bottom and side-by-side panes |
| `-c $PWD` | Set working directory for pane |
| `select-pane` | Change active pane |
| `kill-window -t "$TMUX_PANE"` | Close the REPL's own window (from the editor wrapper or an entr pane) |
| `$TMUX_PANE` variable | Pane ID set by tmux in each pane; identifies the REPL's window |
| `$TMUX` variable | Detect if already in tmux session |

---

## Configuration Variables

```bash
replfile="$HOME/.repl.awk"   # User's AWK file (fixed; not configurable)
TMPDIR=${TMPDIR:-/tmp}       # Directory for awkrepl-* temp files
EDITOR=${EDITOR:-nano}       # Text editor
TRACE=1                      # (optional) 'set -x' inside awkrepl()
```

---

## Summary

### Architecture Highlights

1. **3-pane tmux window** with dedicated responsibilities:
   - Pane 0: Editor (user input)
   - Pane 1: Runner (AWK execution)
   - Pane 2: Formatter (code formatting)

2. **Two independent entr processes**:
   - Pane 1: Watches `~/.repl.awk` → execute AWK
   - Pane 2: Watches `$src` → pretty-print code

3. **Event-driven loop**:
   - File change → command execution → wait for next change
   - No polling loops in awkrepl; entr uses kernel file events

4. **Self-contained scripts**:
   - `_awkrepl_setup` generates `$runner`/`$formatter`/`$cleanup`/`$editpane` and uses `declare -f` to embed the functions they need
   - Runtime still requires external tools: tmux, entr, gawk, sed, xargs (bat/batcat optional)

5. **Cleanup**:
   - The editor pane's wrapper deletes the temp files and closes only its own window when the editor exits (or the window is killed); an entr pane exiting also closes the window. Plus a backstop `rm -f` in `awkrepl()` when not nested in tmux and the session has ended (not on a detach)

### Data Access Flow

```
User → editor (pane 0) → save
      → entr (pane 1) → runner → gawk → output (pane 1)
      → entr (pane 2) → formatter → pretty (pane 2)
      → editor exits → cleanup + kill-window (pane 0 wrapper; backstop rm when not nested and the session is gone)
```

This creates a **reactive development loop** where every save automatically triggers both code execution and formatting feedback.
