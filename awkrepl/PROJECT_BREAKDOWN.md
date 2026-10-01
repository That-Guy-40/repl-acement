# AWK REPL Project Breakdown

## Overview

**awkrepl** is an interactive read-eval-print loop (REPL) for AWK that provides a multi-pane terminal interface using tmux, plus automatic file watching and execution with entr. It enables rapid AWK development with real-time feedback as you edit.

---

## Dependencies

### External Dependencies (Required)
| Package | Purpose | Version |
|---------|---------|---------|
| `gawk` | GNU AWK interpreter, required for `--pretty-print` | Any recent |
| `tmux` | Terminal multiplexer for multi-pane interface | ≥ 2.0 |
| `entr` | File change watcher for event-driven execution | Latest |
| `perl` | Pattern matching for AWK structure detection | Any recent |
| `xargs` | Shell-style splitting/unquoting of `#ARGS` (in `_repl_parse_args`) | Any |
| `bash` | Shell script runner | Any recent |

### External Dependencies (Optional)
| Package | Purpose |
|---------|---------|
| `bat` (or `batcat`) | Syntax-highlighted output for pretty-printed AWK code |
| `nano`, `vim`, `jove`, `emacs` | Text editors (`$EDITOR` variable, defaults to `nano`) |

### Internal Dependencies (BASH Functions)
| Function | Purpose | Exported (`export -f`) | Embedded (`declare -f`) in |
|----------|---------|----------|----------|
| `_sed_in_place()` | Cross-platform `sed -i` wrapper | ✅ Yes | `$runner` |
| `_trim_blanks()` | Remove leading/trailing blank lines (via a `mktemp` file) | ❌ No | `$runner` |
| `_awkrepl_pretty_print()` | Pretty-print AWK code with optional syntax highlighting | ✅ Yes | `$formatter` |
| `_awkrepl_divide()` | Split input file into source/data/args components; strip comments; auto-wrap | ✅ Yes | `$runner` |
| `_repl_parse_args()` | Print `#ARGS` tokens NUL-separated (shell quoting, no globbing/expansion) | ✅ Yes | `$runner` |
| `_awkrepl_setup()` | Create temp files and generate `$runner`, `$formatter`, `$cleanup` | ❌ No | — |
| `awkrepl()` | Main entry point - sets up tmux environment | N/A | — |

### Build Dependencies
| Package | Purpose | Required |
|---------|---------|----------|
| `docker` | Containerization | Optional |
| `make` | Build system | Optional |

---

## Function Dependencies and Interfaces

### Function Call Graph

```
(at source time, top level) 'export -f' for tmux subshells:
    _sed_in_place(), _awkrepl_divide(), _awkrepl_pretty_print(), _repl_parse_args()

awkrepl() [ENTRY POINT]
    │
    ├─ _awkrepl_setup($HOME/.repl.awk)
    │   │
    │   ├─ mktemp "${TMPDIR:-/tmp}/awkrepl-{src,data,args,run,fmt,helpers,cleanup}-XXXXXX"
    │   │
    │   ├─ Embeds functions via 'declare -f' in generated scripts:
    │   │   ├─ $runner:    _sed_in_place, _trim_blanks, _awkrepl_divide, _repl_parse_args
    │   │   └─ $formatter: _awkrepl_pretty_print
    │   │
    │   └─ Generates temporary scripts:
    │       ├─ $runner    → calls _awkrepl_divide() → _repl_parse_args() → runs gawk
    │       ├─ $formatter → calls _awkrepl_pretty_print()
    │       └─ $cleanup   → removes temp files
    │
    ├─ tmux new-session -s awkrepl-<pid> (or 'tmux new-window' when already inside tmux)
    │
    └─ Backstop: if not nested ($TMUX unset) and the named session is gone,
       removes temp files (a detach returns too, but leaves the session running)
```

### Runtime Call Chain

```
User saves ~/.repl.awk
        │
        ▼
entr detects change
        │
        ▼
$runner executes:
    │
    ├─ _awkrepl_divide($replfile, $src, $data, $args)
    │   │
    │   ├─ _sed_in_place() [×3 calls, +1 if auto-wrapping]
    │   │
    │   ├─ _trim_blanks()
    │   │
    │   └─ perl heuristic (decides whether to wrap in { } / END { })
    │
    ├─ _repl_parse_args($args) → gawk argument array
    │
    └─ gawk <#ARGS tokens> -f $helpers -f $src $data
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
    │
    ├─ sleep 1 [wait for writer to finish]
    │
    └─ _awkrepl_pretty_print($src)
        │
        ▼
Formatted code displayed in pane 2
```

---

## Interface at Each Level

### Level 1: User Interface (Tmux Pane 0)
- **Component**: `$EDITOR ~/.repl.awk` (defaults to `nano`)
- **User actions**: Edit AWK source code
- **File path**: `$HOME/.repl.awk`
- **Features**: 
  - Supports `#DATA` section for test input
  - Supports `#ARGS` section for gawk command-line flags
  - Auto-wraps simple AWK statements in `{ }` or `END { }`

### Level 2: Runner Interface (Tmux Pane 1)
- **Component**: `echo $replfile | entr -c $runner`
- **Triggers**: File change events on `~/.repl.awk`
- **Operations**:
  - Clears screen before execution (`-c` flag)
  - Splits input file into source/data/args
  - Executes AWK with `#ARGS` options, helpers, source, and data
  - Prints dimmed info lines for working directory and command

### Level 3: Formatter Interface (Tmux Pane 2)
- **Component**: `echo $src | entr -c $formatter`
- **Triggers**: File change events on temp `$src` file (created by `_awkrepl_setup`, rewritten by runner)
- **Operations**:
  - Waits 1 second for runner to finish (race condition prevention)
  - Pretty-prints AWK source using `gawk --pretty-print`
  - Pipes through `bat` for syntax highlighting if available

### Level 4: AWK Execution Interface
- **Component**: `gawk` command
- **Inputs**:
  - `"${_gawk_args[@]}"` - gawk command-line options (from `#ARGS` lines, tokenized by `_repl_parse_args`)
  - `-f $helpers` - AWK helper functions (`printa`, `printaa`, `printerr`)
  - `-f $src` - User's cleaned AWK source code
  - `$data` - Input data (from `#DATA` section)

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ USER INTERFACE pane 0 (editor)                                  │
│ ~/.repl.awk edited and saved                                    │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ RUNNER pane 1 (file watcher)                                    │
│ entr watches ~/.repl.awk                                        │
│ On change:                                                      │
│   1. Clear pane                                                 │
│   2. Execute $runner                                            │
│      ├─ _awkrepl_divide splits input into:                     │
│      │   - $src (AWK code, cleaned)                            │
│      │   - $data (test input)                                  │
│      │   - $args (gawk flags)                                  │
│      ├─ gawk <#ARGS> -f $helpers -f $src $data                 │
│      └─ Output shown in pane 1                                 │
│      (side effect: $src rewritten)                             │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼ (file change)
┌─────────────────────────────────────────────────────────────────┐
│ FORMATTER pane 2 (file watcher)                                 │
│ entr watches temp $src file                                     │
│ On change:                                                      │
│   1. Clear pane                                                 │
│   2. Execute $formatter                                         │
│      ├─ Sleep 1 second (wait for writer)                       │
│      ├─ _awkrepl_pretty_print($src)                            │
│      └─ Output shown in pane 2                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Design Patterns

### 1. Function Propagation

Two mechanisms for making functions available in subprocesses:

**`export -f`** (exported to tmux subshells):
```bash
export -f _sed_in_place          # Available to tmux shells
export -f _awkrepl_divide
export -f _awkrepl_pretty_print
export -f _repl_parse_args
```

**`declare -f`** (inlined into scripts):
```bash
# $runner
$(declare -f _sed_in_place _trim_blanks _awkrepl_divide _repl_parse_args)
# $formatter
$(declare -f _awkrepl_pretty_print)
```

### 2. Event-Driven Execution Loop

The `entr` program provides an infinite event loop:
```
Wait for file change → Execute command → Wait...
```

Each pane runs one `entr` process, creating two parallel event loops.

### 3. Auto-Wrapping Heuristics

Simple AWK statements are automatically wrapped:

- **With `#DATA`**: Wrapped in `{ }` (applies to each input line)
- **Without `#DATA`**: Wrapped in `END { }` (runs once at EOF)

Pattern detection (Perl one-liner), applied to the **first line only** of the
comment-stripped source:
- Matches (no wrapping): a line starting with `{`, `BEGIN`, `END`, `NR`, `NF`,
  a field reference `$<digit>`, or `/` (regex), optionally after a `(`
- Non-matches get automatic wrapping

### 4. Cleanup on Exit

Two tmux hooks for resource cleanup. The `[0]`/`[1]` are indices into the
`pane-exited` hook array (not pane numbers), so when **any** pane exits both
run, in order:
- `pane-exited[0]`: run the `$cleanup` script (removes all seven temp files)
- `pane-exited[1]`: kill the entire window

Backstop: because the hooks are unreliable on some tmux builds, when awkrepl
started a new tmux session (not nested; `$TMUX` unset) it also removes the temp
files itself once `tmux new-session` returns **and** `tmux has-session` shows the
named session (`awkrepl-<pid>`) is gone. A detach (`C-b d`) also makes
`tmux new-session` return, but the session is still alive, so its files are
kept and you can reattach. In the nested (`tmux new-window`) case cleanup is left
to the hook.

---

## File Organization

```
awkrepl/
├── awkrepl                  # Main script (executable)
├── Makefile                 # Targets: help, build, run, test, publish
├── Dockerfile               # Docker image definition
├── examples.awk             # Demonstration AWK code
├── README.md                # Project documentation
├── PROJECT_BREAKDOWN.md     # This file
├── ARCHITECTURE_DIAGRAMS.md # Diagrams
├── TMUX_ARCHITECTURE.md     # tmux/entr design notes
├── demo.gif                 # Demo screenshot
└── tests/                   # smoke/ and integration/ suites (make test)
```

---

## Summary

awkrepl is an elegant solution that combines:
- **tmux** for terminal interface management
- **entr** for automatic re-execution on file changes
- **gawk** for AWK interpretation and pretty-printing
- **bash** for orchestration and file manipulation

The result is a REPL-like experience where coding, testing, and debugging happen in a single terminal window with immediate feedback.
