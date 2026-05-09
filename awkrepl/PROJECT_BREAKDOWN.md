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
| `bash` | Shell script runner | Any recent |

### External Dependencies (Optional)
| Package | Purpose |
|---------|---------|
| `bat` | Syntax-highlighted output for pretty-printed AWK code |
| `nano`, `vim`, `jove`, `emacs` | Text editors (`$EDITOR` variable, defaults to `nano`) |

### Internal Dependencies (BASH Functions)
| Function | Purpose | Exported |
|----------|---------|----------|
| `_sed_in_place()` | Cross-platform `sed -i` wrapper | ✅ Yes |
| `_trim_blanks()` | Remove leading/trailing blank lines | ❌ No (embedded) |
| `_awkrepl_pretty_print()` | Pretty-print AWK code with optional syntax highlighting | ✅ Yes |
| `_awkrepl_divide()` | Split input file into source/data/args components | ✅ Yes |
| `awkrepl()` | Main entry point - sets up tmux environment | N/A |

### Build Dependencies
| Package | Purpose |
|---------|---------|
| `docker` | Containerization | Optional |
| `make` | Build system | Optional |

---

## Function Dependencies and Interfaces

### Function Call Graph

```
awkrepl() [ENTRY POINT]
    │
    ├─ Embeds functions via 'declare -f' in generated scripts
    │   ├─ _sed_in_place()
    │   ├─ _trim_blanks()
    │   ├─ _awkrepl_divide()
    │   └─ _awkrepl_pretty_print()
    │
    ├─ Exports functions for tmux subshells via 'export -f':
    │   ├─ _sed_in_place()      [exported]
    │   ├─ _awkrepl_divide()    [exported]
    │   └─ _awkrepl_pretty_print() [exported]
    │
    └─ Generates temporary scripts:
        ├─ $runner   → calls _awkrepl_divide() → runs gawk
        ├─ $formatter → calls _awkrepl_pretty_print()
        └─ $cleanup  → removes temp files
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
    │   ├─ _sed_in_place() [×3 calls]
    │   │
    │   └─ _trim_blanks()
    │
    └─ gawk -f $helpers -f $src $data
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
- **Component**: `entr -c './$runner'`
- **Triggers**: File change events on `~/.repl.awk`
- **Operations**:
  - Clears screen before execution (`-c` flag)
  - Splits input file into source/data/args
  - ExecutesAWK with helpers, source, and data
  - Prints dimmed info lines for working directory and command

### Level 3: Formatter Interface (Tmux Pane 2)
- **Component**: `entr -c './$formatter'`
- **Triggers**: File change events on temp `$src` file (created by runner)
- **Operations**:
  - Waits 1 second for runner to finish (race condition prevention)
  - Pretty-prints AWK source using `gawk --pretty-print`
  - Pipes through `bat` for syntax highlighting if available

### Level 4: AWK Execution Interface
- **Component**: `gawk` command
- **Inputs**:
  - `$(cat $args)` - gawk command-line flags (from `#ARGS` lines)
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
│      ├─ gawk -f $helpers -f $src $data                         │
│      └─ Output shown in pane 1                                 │
│      (side effect: $src rewritten)                             │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼ (file change)
┌─────────────────────────────────────────────────────────────────┐
│ FORMATTER pane 2 (file watcher)                                 │
│ entr watches temp $src file                                     │
│ On change:                                                      │
│   1. Sleep 1 second (wait for writer)                           │
│   2. Clear pane                                                 │
│   3. Execute $formatter                                         │
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
```

**`declare -f`** (inlined into scripts):
```bash
$(declare -f _sed_in_place _trim_blanks _awkrepl_divide)
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

Pattern detection (Perl one-liner):
- Matches: `{...}`, `BEGIN`, `END`, `NR`, `NF`, regex patterns
- Non-matches get automatic wrapping

### 4. Cleanup on Exit

Two tmux hooks for resource cleanup:
- `pane-exited[0]`: Editor pane exit → run cleanup script
- `pane-exited[1]`: Runner pane exit → kill entire window

---

## File Organization

```
awkrepl/
├── awkrepl           # Main script (executable)
├── Makefile          # Build targets (build, run, publish)
├── Dockerfile        # Docker image definition
├── examples.awk      # Demonstration AWK code
├── README.md         # Project documentation
└── demo.gif          # Demo screenshot
```

---

## Summary

awkrepl is an elegant solution that combines:
- **tmux** for terminal interface management
- **entr** for automatic re-execution on file changes
- **gawk** for AWK interpretation and pretty-printing
- **bash** for orchestration and file manipulation

The result is a REPL-like experience where coding, testing, and debugging happen in a single terminal window with immediate feedback.
