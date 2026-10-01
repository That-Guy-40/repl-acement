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
local session="awkrepl-$$"                                   # Step A
local -a launch=(new-session -s "$session")
if [[ -n "${TMUX:-}" ]]; then launch=(new-window); fi
tmux "${launch[@]}" -n 'awkrepl'                              \
  "${EDITOR:-nano}" "$replfile" \;                             \   # Step B
  split-window    -c "$PWD"                                    \   # Step C
    "echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER" \;      \   # Step D
  split-window -h -c "$PWD"                                    \   # Step E
    "echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER" \;        \   # Step F
  select-pane -t 1 \;                                          \   # Step G
  select-pane -t 2 \;                                          \   # Step H
  select-pane -t 0 \;                                          \   # Step I
  set-hook 'pane-exited[0]' "run-shell $REPL_Q_CLEANUP" \;   \   # Step J
  set-hook 'pane-exited[1]' kill-window                            # Step K
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
"${EDITOR:-nano}" "$replfile"
```
- First pane (pane 0) opens the editor with `~/.repl.awk` (created with `touch` if missing)
- Uses `$EDITOR` or defaults to `nano`
- This pane initially fills the window; after Step C it occupies the **top ~50%**

#### Step C: Split Top/Bottom (Pane 1)
```bash
split-window -c "$PWD" "echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER"
```
- Splits pane 0 into top and bottom halves (`split-window` defaults to `-v`)
- Creates pane 1 below at ~50% height; pane 1 becomes the active pane
- `-c "$PWD"` sets working directory

#### Step D: entr #1 - Runner (Pane 1)
```bash
echo $REPL_Q_REPLFILE | entr -c $REPL_Q_RUNNER
```
- **Watches**: `$replfile` = `$HOME/.repl.awk`
- **Runs once at startup**, then again on each change:
  - Clear screen (`-c`)
  - Execute the `$runner` script (by absolute path)
- `$runner` executes: `_awkrepl_divide` + `_repl_parse_args` + `gawk`

#### Step E: Split Left/Right (Pane 2)
```bash
split-window -h -c "$PWD" "echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER"
```
- Splits the active pane (pane 1) side by side (`-h` flag)
- Creates pane 2 to the right at ~50% width

#### Step F: entr #2 - Formatter (Pane 2)
```bash
echo $REPL_Q_SRC | entr -c $REPL_Q_FORMATTER
```
- **Watches**: `$src` = temp file (`${TMPDIR:-/tmp}/awkrepl-src-XXXXXX`)
- **Runs once at startup**, then again on each change:
  - Clear screen (`-c`)
  - Execute the `$formatter` script (by absolute path)
- `$formatter` executes: `sleep 1`, then `_awkrepl_pretty_print`

#### Steps G-I: Pane Selection
```bash
select-pane -t 1 \;  # Select pane 1 (runner)
select-pane -t 2 \;  # Select pane 2 (formatter)
select-pane -t 0 \;  # Select pane 0 (editor) ← focus ends here
```
- The last command leaves focus on the editor (pane 0), so the user can start typing immediately after awkrepl starts
- Side effect of the sequence: pane 2 becomes tmux's "last pane"

#### Steps J-K: Cleanup Hooks
```bash
set-hook 'pane-exited[0]' "run-shell $REPL_Q_CLEANUP" \;
set-hook 'pane-exited[1]' kill-window
```
- These are **session** hooks (no `-p`/`-w`/`-t`), and `[0]`/`[1]` are **indices in the `pane-exited` hook array, not pane numbers**
- Whenever **any** pane in the session exits, tmux runs both entries in order: the `$cleanup` script (`run-shell`), then `kill-window` (on the session's current window)
- In practice: quitting the editor (or an entr pane dying) deletes the temp files and closes the awkrepl window
- **Note**: the script's own comment says these hooks are unreliable on some tmux builds, which is why `awkrepl()` also has a backstop `rm -f` (see Cleanup Mechanism)

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
# (embeds _sed_in_place, _trim_blanks, _awkrepl_divide, _repl_parse_args via declare -f)
_awkrepl_divide ~/.repl.awk $src $data $args
_gawk_args=()
while IFS= read -r -d '' _a; do _gawk_args+=( "$_a" ); done < <(_repl_parse_args $args)
echo "# work dir: $PWD"
echo "# command:  gawk ${_gawk_args[*]} -f $helpers -f $src $data"
gawk "${_gawk_args[@]}" -f $helpers -f $src $data   # AWK execution
```

`_repl_parse_args` uses `xargs` to split the `#ARGS` text into NUL-separated
tokens, honoring shell quotes but performing no globbing or expansion. The two
`echo` header lines are wrapped in `tput setaf 0` / `tput sgr0` (evaluated when
the script is generated).

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
time to finish rewriting `$src`. `_awkrepl_divide` rewrites `$src` several
times in a row (`sed ... w`, several `sed -i` passes, and `_trim_blanks`'s
temp-file `mv`), each of which can fire entr #2:

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
│     ├─ Extract #ARGS line(s) → $args                 │
│     ├─ Split at #DATA → $src / $data                 │
│     ├─ Clean source (remove headers/comments)        │
│     ├─ Auto-wrap in { } or END { } if needed         │
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

### Trigger 1: Pane Exit Hooks

```bash
set-hook 'pane-exited[0]' "run-shell $REPL_Q_CLEANUP" \;
set-hook 'pane-exited[1]' kill-window
```

Both hook entries run, in order, whenever any pane in the session exits:

**`pane-exited[0]`** runs the generated `$cleanup` script:
```bash
#!/usr/bin/env bash
rm -f $src $data $args $runner $formatter $helpers $cleanup   # %q-quoted paths
```

**`pane-exited[1]`**:
```bash
kill-window  # Close the (current) tmux window
```

### Trigger 2: Backstop in `awkrepl()`

Because the hooks are unreliable on some tmux builds, `awkrepl()` removes the
temp files itself after `tmux new-session` returns, **only when not nested in
tmux** (`$TMUX` unset) **and only once its named session is gone**.
`tmux new-session` also returns when the client merely detaches (`C-b d`); the
detached session still needs its files, so they are left alone and you can
reattach later. When nested, `tmux new-window` returns immediately while the
window is still live, so cleanup is left to the hook.

```bash
if [[ -z "${TMUX:-}" ]] && ! tmux has-session -t "=$session" 2>/dev/null; then
    rm -f "$REPL_SRC" "$REPL_DATA" "$REPL_ARGS" "$REPL_RUNNER" \
          "$REPL_FORMATTER" "$REPL_CLEANUP" "${REPL_HELPERS:-}"
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
| `set-hook` | Register event handlers |
| `run-shell` | Execute external commands from hooks |
| `$TMUX` variable | Detect if already in tmux session |

---

## Configuration Variables

```bash
replfile="$HOME/.repl.awk"   # User's AWK file (fixed; not configurable)
TMPDIR=${TMPDIR:-/tmp}       # Directory for awkrepl-* temp files
EDITOR=${EDITOR:-nano}       # Text editor
TRACE=1                      # (optional) 'set -x' inside awkrepl()
DEBUG=1                      # (optional) run the auto-wrap perl check under 'perl -d'
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
   - `_awkrepl_setup` generates `$runner`/`$formatter`/`$cleanup` and uses `declare -f` to embed the functions they need
   - Runtime still requires external tools: tmux, entr, gawk, perl, sed (bat/batcat optional)

5. **Cleanup**:
   - tmux hooks delete temp files on pane exit, plus a backstop `rm -f` in `awkrepl()` when not nested in tmux and the session has ended (not on a detach)

### Data Access Flow

```
User → editor (pane 0) → save
      → entr (pane 1) → runner → gawk → output (pane 1)
      → entr (pane 2) → formatter → pretty (pane 2)
      → cleanup (pane exit hook; backstop rm when not nested and the session is gone)
```

This creates a **reactive development loop** where every save automatically triggers both code execution and formatting feedback.
