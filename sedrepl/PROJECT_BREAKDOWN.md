# SEDREPL Project Breakdown

## Overview

**sedrepl** is an interactive read-eval-print loop (REPL) for sed that provides a multi-pane terminal interface using tmux, plus automatic file watching and execution with entr. It enables rapid sed script development with real-time feedback as you edit.

sedrepl mirrors the architecture of awkrepl but is tailored for sed's line-by-line processing model.

---

## Dependencies

### External Dependencies (Required)
| Package | Purpose | Version |
|---------|---------|---------|
| `sed` | Stream editor for text processing | GNU sed or BSD sed |
| `tmux` | Terminal multiplexer for multi-pane interface | ≥ 2.0 |
| `entr` | File change watcher for event-driven execution | Latest |
| `bash` | Shell script runner | Any recent |
| `xargs` | Shell-style splitting/unquoting of `#ARGS` (findutils) | Any |

### External Dependencies (Optional)
| Package | Purpose |
|---------|---------|
| `bat` (or `batcat`) | Syntax-highlighted display of the sed script (uses bat's `awk` syntax; bat has no sed syntax) |

### Build Dependencies
| Package | Purpose |
|---------|---------|
| `docker` | Containerization (optional) |
| `make` | Build system (optional) |

---

## Internal Dependencies (BASH Functions)

| Function | Purpose | Embedded (`declare -f`) in |
|----------|---------|----------|
| `_sed_in_place()` | Cross-platform `sed -i` wrapper | `$runner` |
| `_sedrepl_pretty_print()` | Syntax-check and display sed script | `$formatter` |
| `_sedrepl_divide()` | Split input file at the first `#DATA` into source and data, then extract `#ARGS` from the source part only (`sed -n -e "s/$argshdr/\3/p" "$src" > "$args"`), so an `#ARGS` line after `#DATA` is an ordinary data row (`#DATA` alone on its line; `#ARGS`/`#ARG`/`#ARGUMENT(S)` followed by nothing or by options starting with `-`; case-insensitive, optional colon) | `$runner` |
| `_repl_parse_args()` | Split the args file into NUL-separated tokens via `xargs` (quotes honored, no glob/variable expansion); on an unmatched quote, warns on stderr and splits on whitespace, keeping quote characters literally | `$runner` |
| `_sedrepl_setup()` | Create temp files under `${TMPDIR:-/tmp}/sedrepl-*` and generate the runner/formatter/cleanup/editor-pane scripts (seven temp files: src, data, args, run, fmt, cleanup, edit); sets `REPL_*` globals | — |
| `sedrepl()` | Main entry point - calls `_sedrepl_setup()`, sets up tmux environment | — |

### Function Call Graph

```
sedrepl() [ENTRY POINT]
    │
    ├─ _sedrepl_setup() — creates temp files and generated scripts:
    │   ├─ $runner    (embeds _sed_in_place, _sedrepl_divide, _repl_parse_args)
    │   │              → _sedrepl_divide() → _repl_parse_args() → runs sed
    │   ├─ $formatter (embeds _sedrepl_pretty_print)
    │   │              → sleep 1 → _sedrepl_pretty_print()
    │   ├─ $cleanup   → removes all temp files
    │   └─ $editpane  → runs $EDITOR ~/.repl.sed; when the editor exits (or on
    │                   SIGHUP/SIGTERM) runs $cleanup, then
    │                   'tmux kill-window -t $TMUX_PANE' (its own window only)
    │
    ├─ tmux: new session 'sedrepl-<pid>' (or 'new-window' if nested in tmux)
    │        pane 0: $editpane
    │        pane 1: echo ~/.repl.sed | entr -c $runner; tmux kill-window …
    │        pane 2: echo $src | entr -c $formatter; tmux kill-window …
    │        (if either entr exits, the window closes; pane 0's wrapper then
    │         cleans up). No tmux hooks are used.
    │
    └─ Backstop cleanup: if not nested in tmux ($TMUX unset), removes the
       temp files itself once 'tmux new-session' returns and the named
       session (sedrepl-<pid>) is gone; a detach leaves it running
```

Nothing is exported with `export -f`: each generated script embeds the
functions it needs via `declare -f`, so it is self-contained.

---

## Interface at Each Level

### Level 1: User Interface (Tmux Pane 0)
- **Component**: `$editpane` wrapper running `$EDITOR ~/.repl.sed` (defaults
  to `nano`); on editor exit it removes the temp files and closes the REPL's
  window
- **User actions**: Edit sed script
- **File path**: `$HOME/.repl.sed`
- **Features**: 
  - Supports `#DATA` section for test input
  - Supports `#ARGS` section for sed command-line flags

### Level 2: Runner Interface (Tmux Pane 1)
- **Component**: `echo ~/.repl.sed | entr -c $runner; tmux kill-window -t "$TMUX_PANE"`
- **Triggers**: File change events on `~/.repl.sed`
- **Operations**:
  - Clears screen before execution (`-c` flag)
  - Splits input file into source/data/args (`#ARGS` is read from the
    source part only; after `#DATA` it is data)
  - Parses `#ARGS` with `_repl_parse_args()` into an array
  - Prints dimmed info lines (`tput dim`) for working directory and command
  - Displays the sed script (`bat -l awk` / `batcat -l awk`, or `cat`)
  - Executes: `sed "${_sed_args[@]}" -f $src $data`

### Level 3: Formatter Interface (Tmux Pane 2)
- **Component**: `echo $src | entr -c $formatter; tmux kill-window -t "$TMUX_PANE"`
- **Triggers**: File change events on temp `$src` file (created by runner)
- **Operations**:
  - Waits 1 second for runner to finish (race condition prevention)
  - Syntax-checks sed script by running `sed -n -f $src /dev/null` once; on a
    non-zero exit prints an `ERROR parsing sed script` header with sed's error
    message
  - Displays sed script using `cat` or `bat`/`batcat` (`-l awk`) for syntax
    highlighting

---

## Key Differences from AWKREPL

### 1. No Automatic Wrapping
Sed operates on every line of input by default, so sedrepl doesn't need AWKREPL's auto-wrapping logic with `BEGIN { }` or `END { }`.

### 2. Simpler Syntax Checking
sedrepl uses: `sed -n -f "$src" /dev/null` for syntax checking, which prints nothing on success and an error on failure.

### 3. Data Flow
```
User saves ~/.repl.sed
        │
        ▼
entr detects change (pane 1)
        │
        ▼
$runner executes:
    ├─ _sedrepl_divide() splits input at #DATA, then extracts #ARGS
    │                     from the source part
    ├─ _repl_parse_args() reads #ARGS
    ├─ prints header + script
    └─ sed "${_sed_args[@]}" -f $src $data
        │
        ▼
Output displayed in pane 1

$src rewritten
        │
        ▼
entr detects change (pane 2)
        │
        ▼
$formatter executes:
    ├─ sleep 1
    └─ _sedrepl_pretty_print() syntax-check + cat/bat
        │
        ▼
sed script displayed in pane 2
```

---

## File Organization

```
sedrepl/
├── sedrepl              # Main script (executable)
├── Makefile             # help/build/run/test/publish targets
├── Dockerfile           # Docker image definition
├── examples.sed         # Demonstration sed code
├── README.md            # Project documentation
├── PROJECT_BREAKDOWN.md # This file
└── tests/               # helpers.sh, smoke/ and integration/ suites
```

---

## Example Usage

### Basic sed Script
```sed
# Replace 'chr' with 'chromosome'
s/chr/chromosome/
```

### With Test Data
```sed
s/chr/chromosome/

#DATA
chr1	100	200
chr8	500	600
```

### With Command-Line Flags
```sed
#ARGS -n
/^chr8/p

#DATA
chr1	100	200
chr8	500	600
```

---

## Key Features

1. **Multi-pane tmux session** - Editor, runner, and formatter panes
2. **Event-driven execution** - Runs on file save via entr
3. **Inline sed syntax checking** - Validates syntax on save
4. **#DATA sections** - Quick test input
5. **#ARGS sections** - Pass sed flags like `-n`

---

## Summary

sedrepl provides a REPL-like environment for sed development where:
- **One save** triggers **two reactions** (execution and formatting)
- **No polling** - uses kernel file events via entr
- **Self-contained** - scripts embed functions via `declare -f`
- **Clean exit** - temp files deleted automatically (by the editor pane's wrapper when the editor exits or the window is killed, plus a backstop `rm` when not nested in tmux and the session has ended); only the REPL's own window is closed, so it is safe inside an existing tmux session
