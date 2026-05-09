# AWK REPL: Tmux Integration and Event-Driven Architecture

## Overview

awkrepl creates a **three-pane tmux session** that implements a reactive, event-driven interactive development environment. This document explains how tmux and entr work together to create the user-facing interface.

---

## Tmux Session Layout

### Pane Structure

```
┌────────────────────────────────────────┐
│   PANE 0 (50% height)                 │
│   ┌─────────────────────────────────┐  │
│   │  $EDITOR ~/.repl.awk          │  │
│   │  ┌─────────────────────────┐    │  │
│   │  │  Text editor with       │    │  │
│   │  │  ~/.repl.awk open       │    │  │
│   │  │  (nano vim, jove, etc.) │    │  │
│   │  └─────────────────────────┘    │  │
│   └─────────────────────────────────┘  │
├───────────────────┬────────────────────┤
│   PANE 1          │   PANE 2           │
│   (bottom-left)   │   (bottom-right)   │
│   ┌───────────────┤   ┌───────────────┐│
│   │ entr          │   │ entr          ││
│   │ ~/.repl.awk   │   │ $src (temp)   ││
│   │ → $runner     │   │ → $formatter  ││
│   │ gawk output   │   │ pretty-print  ││
│   └───────────────┘   └───────────────┘│
└───────────────────┴─────────────────────┘
```

**Pane 0 (Top-left)**: 50% height - Your text editor  
**Pane 1 (Bottom-left)**: Full width - AWK execution output  
**Pane 2 (Bottom-right)**: 50% width - Pretty-printed AWK code  

---

## Tmux Command Breakdown

### Command Structure (Lines 217-232)

```bash
tmux new${TMUX:+w} -n 'awkrepl'                        # Step A
  "${EDITOR:-nano}" "$replfile"                         # Step B
  split-window    -c "$PWD"                             # Step C
    "echo '$replfile' | entr -c './$runner'"            # Step D
  split-window -h -c "$PWD"                             # Step E
    "echo '$src'      | entr -c './$formatter'"         # Step F
  select-pane -t 1 \;                                  # Step G
  select-pane -t 2 \;                                  # Step H
  select-pane -t 0 \;                                  # Step I
  set-hook 'pane-exited[0]' "run-shell './$cleanup'" \; # Step J
  set-hook 'pane-exited[1]' kill-window                # Step K
```

### Step-by-StepExplanation

#### Step A: Create Session or Window
```bash
tmux new${TMUX:+w} -n 'awkrepl'
```
- If **outside tmux**: Creates new session named `awkrepl`
- If **inside tmux** (`$TMUX` is set): Creates new window in current session named `awkrepl`

#### Step B: Create Pane 0 (Editor)
```bash
"${EDITOR:-nano}" "$replfile"
```
- First pane (pane 0) opens the editor with `~/.repl.awk`
- Uses `$EDITOR` or defaults to `nano`
- This pane occupies the **top 50%** initially

#### Step C: Split Vertically (Pane 1)
```bash
split-window -c "$PWD" "echo '$replfile' | entr -c './$runner'"
```
- Splits pane 0 **vertically** (default `split-window`)
- Creates pane 1 below at 50% height
- `-c "$PWD"` sets working directory
- Runs: `echo ~/.repl.awk | entr -c './$runner'`

#### Step D: entr #1 - Runner (Pane 1)
```bash
echo '$replfile' | entr -c './$runner'
```
- **Watches**: `$replfile` = `$HOME/.repl.awk`
- **Action on change**:
  - Clear screen (`-c`)
  - Execute `$runner` script
- `$runner` executes: `_awkrepl_divide` + `gawk`

#### Step E: Split Horizontally (Pane 2)
```bash
split-window -h -c "$PWD" "echo '$src' | entr -c './$formatter'"
```
- Splits pane 1 **horizontally** (`-h` flag)
- Creates pane 2 to the right at 50% width
- Runs: `echo temp-src-file | entr -c './$formatter'`

#### Step F: entr #2 - Formatter (Pane 2)
```bash
echo '$src' | entr -c './$formatter'
```
- **Watches**: `$src` = temp file (`.awkrepl-src-XXXXXX`)
- **Action on change**:
  - Clear screen (`-c`)
  - Execute `$formatter` script
- `$formatter` executes: `_awkrepl_pretty_print`

#### Steps G-I: Pane Selection
```bash
select-pane -t 1 \;  # Select pane 1 (runner)
select-pane -t 2 \;  # Select pane 2 (formatter)
select-pane -t 0 \;  # Select pane 0 (editor) ← focus returns here
```
- These commands traverse panes to return focus to editor (pane 0)
- This is so the user can start typing immediately after awkrepl starts

#### Steps J-K: Cleanup Hooks
```bash
set-hook 'pane-exited[0]' "run-shell './$cleanup'" \;  # Cleanup on editor exit
set-hook 'pane-exited[1]' kill-window                  # Kill on runner exit
```
- **`pane-exited[0]`**: When editor pane exits, run cleanup script
- **`pane-exited[1]`**: When runner pane exits, kill entire window
- **Note**: These hooks have reliability issues in tmux 3.1c (Docker image)

---

## entr: Event-Driven File Watcher

### How entr Works

entr is a **file descriptor multiplexer** that monitors filesystem events:

```bash
echo file | entr command
```

1. **`echo file`** - Sends the file path to entr's stdin
2. **`entr -c command`** - Watch the file and execute `command` on change

### entr's Event Loop

```
entr → inotify/kqueue → wait for file event → execute command → loop
```

**Linux**: Uses `inotify`  
**BSD/macOS**: Uses `kqueue`  
**Process**: Blocking `read()` on file descriptor

### Two entr Processes in awkrepl

#### entr #1: Runner (Pane 1)

```bash
echo "$HOME/.repl.awk" | entr -c './$runner'
```

| Aspect | Detail |
|------|------|
| **File watched** | `$HOME/.repl.awk` (user's AWK source) |
| **Trigger** | File write/save event |
| **Command executed** | `$runner` script |
| **Purpose** | Execute AWK and show output |

**`$runner` script (pseudocode):**
```bash
#!/usr/bin/env bash
# (embeds helper functions)
_awkrepl_divide ~/.repl.awk $src $data $args
cmd="gawk $(cat $args) -f $helpers -f $src $data"
echo "# work dir: $PWD"
echo "# command:  $cmd"
$cmd  # AWK execution
```

#### entr #2: Formatter (Pane 2)

```bash
echo "$src" | entr -c './$formatter'
```

| Aspect | Detail |
|------|------|
| **File watched** | `$src` (temp file created by runner) |
| **Trigger** | File write when runner rewrites source |
| **Command executed** | `$formatter` script |
| **Purpose** | Pretty-print AWK with syntax highlighting |

**`$formatter` script (pseudocode):**
```bash
#!/usr/bin/env bash
# (embeds pretty-print function)
sleep 1  # Wait for runner to finish
_awkrepl_pretty_print $src
```

### Why `sleep 1` in Formatter?

The `sleep 1` prevents a **race condition**:

```
entr triggers $formatter                entr triggers $runner
        │                                      │
        ▼                                      ▼
    sleep 1                            _awkrepl_divide
        │                                      │
        ▼                                      ▼
    read $src                         rewrite $src
        │                                      │
        └───────► incomplete read ◄─────────────┘
```

Without the sleep, formatter might read `$src` while runner is still writing it.

---

## Event Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ USER: Saves ~/.repl.awk                             │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────┐
│ entr #1 (pane 1):                                   │
│   watches ~/.repl.awk                               │
│   ┌─ event: file modified ─────────┐                │
│   │  → clear screen ( Entr: -c)    │                │
│   │  → execute $runner             │                │
│   └────────────────────────────────┘                │
        │                                              │
        ▼                                              │
┌──────────────────────────────────────────────────────┐
│ $runner executes:                                   │
│   _awkrepl_divide ~/.repl.awk $src $data $args     │
│     ├─ Extract #ARGS line                          │
│     ├─ Split at #DATA                              │
│     ├─ Clean source (remove headers/comments)      │
│     └─ Rewrite $src (cleaned)  ────────┐           │
│                                        │           │
│   gawk -f $helpers -f $src $data       │           │
│     └─> output in pane 1               │           │
│                                        │           │
│   (side effect: $src rewritten) ───────┘           │
└──────────────────────────────────────────────────────┘
                    │
                    ▼ (file change)
┌──────────────────────────────────────────────────────┐
│ entr #2 (pane 2):                                   │
│   watches $src                                      │
│   ┌─ event: file modified ─────────┐                │
│   │  → clear screen                 │                │
│   │  → sleep 1                      │                │
│   │  → execute $formatter           │                │
│   └────────────────────────────────┘                │
        │                                              │
        ▼                                              │
┌──────────────────────────────────────────────────────┐
│ $formatter executes:                                │
│   sleep 1                                           │
│   _awkrepl_pretty_print $src                       │
│     ├─ gawk --pretty-print -f $src                 │
│     └─ pipe through bat (if available)             │
│   └─> formatted code in pane 2                     │
└──────────────────────────────────────────────────────┘
```

---

## File Change Triggers

### Triggered Files

| entr instance | File watched | File type | Created by | Trigger |
|---|---|---|---|-------|
| **entr #1** | `$HOME/.repl.awk` | User's AWK source | User (in editor) | File save in editor |
| **entr #2** | `.awkrepl-src-XXXXXX` | Cleaned source extract | `_awkrepl_divide()` in `$runner` | Runner rewrites temp file |

### Trigger Chain

1. User saves `~/.repl.awk` in editor
2. entr #1 detects change
3. `$runner` executes and rewrites `$src`
4. entr #2 detects change in `$src`
5. `$formatter` executes

**Result**: One save-event triggers **both panes** sequentially

---

## The `AWKHELPERS` Library

The `awkrepl` function creates a temp file with helper functions:

```bash
AWKHELPERS='# vim: ft=awk
    function printa(a,  name,fs,l,i) {
        # Print numeric array
    }
    function printaa(a,  name,fs,l,n,i) {
        # Print associative array
    }
    function printerr(msg) {
        # Print error to stderr
    }'
```

These helpers are included in all AWK executions via `-f $helpers`.

---

## Cleanup Mechanism

### Trigger: Panes Exit

```bash
set-hook 'pane-exited[0]' "run-shell './$cleanup'" \;
set-hook 'pane-exited[1]' kill-window
```

**`pane-exited[0]` (Editor exit)**:
```bash
# Cleanup temp files
rm -f '$src' '$data' '$args' '$runner' '$formatter' '$helpers' '$cleanup'
```

**`pane-exited[1]` (Runner exit)**:
```bash
kill-window  # Close entire tmux window
```

---

## Tmux Features Used

| Feature | Purpose in awkrepl |
|---------|-------------------|
| `tmux new` | Start new session |
| `tmux neww` | Create new window (when in tmux) |
| `split-window` | Create vertical/horizontal panes |
| `-c $PWD` | Set working directory for pane |
| `select-pane` | Change active pane |
| `set-hook` | Register event handlers |
| `run-shell` | Execute external commands from hooks |
| `$TMUX` variable | Detect if already in tmux session |

---

## Configuration Variables

```bash
replfile="$HOME/.repl.awk"   # User's AWK file
pref=.awkrepl                # Temp file prefix
EDITOR=${EDITOR:-nano}       # Text editor
```

---

## Summary

### Architecture Highlights

1. **3-pane tmux session** with dedicated responsibilities:
   - Pane 0: Editor (user input)
   - Pane 1: Runner (AWK execution)
   - Pane 2: Formatter (code formatting)

2. **Two independent entr processes**:
   - Pane 1: Watches `~/.repl.awk` → execute AWK
   - Pane 2: Watches `$src` → pretty-print code

3. **Event-driven loop**:
   - File change → command execution → wait for next change
   - No loops or polling, entr uses kernel file events

4. **Self-contained scripts**:
   - Uses `declare -f` to embed functions
   - No external dependencies beyond tmux

5. **Cleanup hooks**:
   - Automatic temp file deletion on exit

### Data Access Flow

```
User → editor (pane 0) → save
      → entr (pane 1) → runner → gawk → output (pane 1)
      → entr (pane 2) → formatter → pretty (pane 2)
      → cleanup (pane 0 exit)
```

This creates a **reactive development loop** where every save automatically triggers both code execution and formatting feedback.
