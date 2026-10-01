# AWK REPL Project Breakdown

## Overview

**awkrepl** is an interactive read-eval-print loop (REPL) for AWK that provides a multi-pane terminal interface using tmux, plus automatic file watching and execution with entr. It enables rapid AWK development with real-time feedback as you edit.

---

## Dependencies

### External Dependencies (Required)
| Package | Purpose | Version |
|---------|---------|---------|
| `gawk` | GNU AWK interpreter, required for `--pretty-print` | Any recent |
| `sed` | Splits `~/.repl.awk` into source/data/args and cleans the source (GNU or BSD) | Any |
| `tmux` | Terminal multiplexer for multi-pane interface | ≥ 2 |
| `entr` | File change watcher for event-driven execution | Latest |
| `xargs` | Shell-style splitting/unquoting of `#ARGS` (in `_repl_parse_args`) | Any |
| `bash` | Shell script runner | Any recent |

### External Dependencies (Optional)
| Package | Purpose |
|---------|---------|
| `bat` (or `batcat`) | Syntax-highlighted output for pretty-printed AWK code |
| `nano`, `vim`, `jove`, `emacs` | Text editors (`$EDITOR` variable, defaults to `nano`) |

### Internal Dependencies (BASH Functions)

Nothing is `export -f`ed: every pane runs a generated script that embeds the
functions it needs with `declare -f`.

| Function | Purpose | Embedded (`declare -f`) in |
|----------|---------|----------|
| `_sed_in_place()` | Cross-platform `sed -i` wrapper | `$runner` |
| `_awkrepl_pretty_print()` | Pretty-print AWK code with optional syntax highlighting | `$formatter` |
| `_awkrepl_parses()` | True if `gawk --pretty-print=/dev/null` can parse the program (parses without running it) | `$runner` |
| `_awkrepl_looks_like_statement()` | For source that parses both as written and wrapped: true if it looks like a statement (starts with a name, no comparison/match operator) rather than a pattern | `$runner` |
| `_awkrepl_divide()` | Split input file into source/data/args components; strip comments and blank lines; auto-wrap (if needed, via `_awkrepl_parses` and `_awkrepl_looks_like_statement`) | `$runner` |
| `_repl_parse_args()` | Print `#ARGS` tokens NUL-separated (shell quoting, no globbing/expansion) | `$runner` |
| `_awkrepl_setup()` | Create temp files and generate `$runner`, `$formatter`, `$cleanup`, `$editpane` | — |
| `awkrepl()` | Main entry point - sets up tmux environment | — |

### Build Dependencies
| Package | Purpose | Required |
|---------|---------|----------|
| `docker` | Containerization | Optional |
| `make` | Build system | Optional |

---

## Function Dependencies and Interfaces

### Function Call Graph

```
awkrepl() [ENTRY POINT]
    │
    ├─ _awkrepl_setup($HOME/.repl.awk)
    │   │
    │   ├─ mktemp "${TMPDIR:-/tmp}/awkrepl-{src,data,args,run,fmt,helpers,cleanup,edit}-XXXXXX"
    │   │
    │   ├─ Embeds functions via 'declare -f' in generated scripts:
    │   │   ├─ $runner:    _sed_in_place, _awkrepl_parses,
    │   │   │              _awkrepl_looks_like_statement, _awkrepl_divide, _repl_parse_args
    │   │   └─ $formatter: _awkrepl_pretty_print
    │   │
    │   └─ Generates temporary scripts:
    │       ├─ $runner    → calls _awkrepl_divide() → _repl_parse_args() → runs gawk
    │       ├─ $formatter → calls _awkrepl_pretty_print()
    │       ├─ $cleanup   → removes temp files (all eight, itself included)
    │       └─ $editpane  → runs $EDITOR ~/.repl.awk; when the editor exits (or on
    │                       SIGHUP/SIGTERM) runs $cleanup, then
    │                       'tmux kill-window -t "$TMUX_PANE"' (its own window only)
    │
    ├─ tmux new-session -s awkrepl-<pid> (or 'tmux new-window' when already inside tmux):
    │   pane 0 runs $editpane; panes 1 and 2 run 'echo … | entr -c …', followed by
    │   'tmux kill-window -t "$TMUX_PANE"' so the window closes if either entr exits
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
    │   ├─ sed > $src, $data [split at the first #DATA]; sed -n p > $args [#ARGS from $src]
    │   │
    │   ├─ _sed_in_place() [×3 calls: strip further #DATA from $data; headers, then comments/blank lines, from $src]
    │   │
    │   ├─ _awkrepl_parses() ×2 [as written, and wrapped in { } / END { }]
    │   │
    │   └─ _awkrepl_looks_like_statement() [only if it parses both ways]
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
- **Component**: the generated `$editpane` wrapper, which runs `$EDITOR ~/.repl.awk` (defaults to `nano`)
- **User actions**: Edit AWK source code
- **File path**: `$HOME/.repl.awk`
- **Features**: 
  - Supports `#DATA` section for test input (the `#DATA` header must be alone on its line)
  - Supports `#ARGS` lines for gawk command-line flags (`#ARGS` followed by nothing, or by options whose first starts with `-`); only in the program section, before `#DATA` (after it, such a line is data)
  - Auto-wraps AWK statements (e.g. `print $1`, `x = 3`, `printa(arr)`) in `{ }` or `END { }`; patterns, rules and functions are left alone
- **On exit**: when the editor exits, the wrapper removes the temp files and closes the REPL's window

### Level 2: Runner Interface (Tmux Pane 1)
- **Component**: `echo $replfile | entr -c $runner`
- **Triggers**: File change events on `~/.repl.awk`
- **Operations**:
  - Clears screen before execution (`-c` flag)
  - Splits input file into source/data/args
  - Executes AWK with `#ARGS` options, helpers, source, and data
  - If `entr` exits, closes the REPL's window (`tmux kill-window -t "$TMUX_PANE"`)
  - Prints dimmed (`tput dim`) info lines for working directory and command

### Level 3: Formatter Interface (Tmux Pane 2)
- **Component**: `echo $src | entr -c $formatter`
- **Triggers**: File change events on temp `$src` file (created by `_awkrepl_setup`, rewritten by runner)
- **Operations**:
  - Waits 1 second for runner to finish (race condition prevention)
  - Pretty-prints AWK source using `gawk --pretty-print`
  - Pipes through `bat` for syntax highlighting if available
  - If `entr` exits, closes the REPL's window (`tmux kill-window -t "$TMUX_PANE"`)

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
│      ├─ _awkrepl_divide splits input into:                      │
│      │   - $src (AWK code, cleaned)                             │
│      │   - $data (test input)                                   │
│      │   - $args (gawk flags)                                   │
│      ├─ gawk <#ARGS> -f $helpers -f $src $data                  │
│      └─ Output shown in pane 1                                  │
│      (side effect: $src rewritten)                              │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼ (file change)
┌─────────────────────────────────────────────────────────────────┐
│ FORMATTER pane 2 (file watcher)                                 │
│ entr watches temp $src file                                     │
│ On change:                                                      │
│   1. Clear pane                                                 │
│   2. Execute $formatter                                         │
│      ├─ Sleep 1 second (wait for writer)                        │
│      ├─ _awkrepl_pretty_print($src)                             │
│      └─ Output shown in pane 2                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Design Patterns

### 1. Function Propagation

One mechanism makes functions available to the panes: `_awkrepl_setup` inlines
them into the generated scripts with `declare -f` (inside unquoted heredocs, so
the function bodies are expanded at generation time). Every pane runs one of
these scripts, so nothing is `export -f`ed:

```bash
# $runner
$(declare -f _sed_in_place _awkrepl_parses _awkrepl_looks_like_statement _awkrepl_divide _repl_parse_args)
# $formatter
$(declare -f _awkrepl_pretty_print)
```

### 2. Event-Driven Execution Loop

The `entr` program provides an infinite event loop:
```
Wait for file change → Execute command → Wait...
```

Each pane runs one `entr` process, creating two parallel event loops.

### 3. Auto-Wrapping

Simple AWK statements are automatically wrapped:

- **With `#DATA`**: Wrapped in `{ }` (applies to each input line)
- **Without `#DATA`**: Wrapped in `END { }` (runs once at EOF)

`gawk` decides: the whole comment-stripped source is parsed both as written and
wrapped, with `_awkrepl_parses` (`gawk --pretty-print=/dev/null`, which parses
the program without running it):
- Parses only as written (rules with actions, function definitions,
  `BEGIN`/`END`, …): left alone
- Parses only wrapped (statements such as `print $1` or `x = 3; print x`):
  wrapped
- Parses neither way: left as written, so the error shown is about the user's
  own code
- Parses both ways (a bare expression, valid as a pattern and as a statement):
  `_awkrepl_looks_like_statement` decides. A pattern-like start (`{`, `!`, `/`,
  `(`, `$`, a number or string literal, `-`, or `NR`/`NF`/`FNR`/`FILENAME`), or
  a comparison/match operator (`==`, `!=`, `<`, `>`, `~`) anywhere in the
  source outside string literals, means a pattern: left alone (`!/re/`, `$NF > 3`, `!seen[$1]++`,
  `length($0) > 5`). Otherwise (it starts with a name: an assignment, a
  function call such as `printa(arr)`, `i++`, `FS = ","`) it's a statement:
  wrapped

### 4. Cleanup on Exit

There are no tmux hooks. Pane 0 runs the generated `$editpane` wrapper
(`${TMPDIR:-/tmp}/awkrepl-edit-XXXXXX`), which runs `$EDITOR ~/.repl.awk`. When
the editor exits, or the wrapper gets SIGHUP/SIGTERM (e.g. the window is
killed), it runs the `$cleanup` script (removes all eight temp files) and then
`tmux kill-window -t "$TMUX_PANE"`, which closes only the REPL's own window,
even when awkrepl runs inside an existing tmux session. Panes 1 and 2 run
`echo … | entr -c …; tmux kill-window -t "$TMUX_PANE"`, so if either `entr`
exits the REPL's window closes too (and the wrapper's SIGHUP trap cleans up).

Backstop: for the rare case the wrapper can't clean up (e.g. it was SIGKILLed),
when awkrepl started a new tmux session (not nested; `$TMUX` unset) it also
removes the temp files itself once `tmux new-session` returns **and**
`tmux has-session` shows the named session (`awkrepl-<pid>`) is gone. A detach
(`C-b d`) also makes `tmux new-session` return, but the session is still alive,
so its files are kept and you can reattach. In the nested (`tmux new-window`)
case cleanup is left to the wrapper.

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
