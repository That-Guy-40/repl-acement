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

### External Dependencies (Optional)
| Package | Purpose |
|---------|---------|
| `bat` | Syntax-highlighted output for sed scripts |

### Build Dependencies
| Package | Purpose |
|---------|---------|
| `docker` | Containerization (optional) |
| `make` | Build system (optional) |

---

## Internal Dependencies (BASH Functions)

| Function | Purpose | Exported |
|----------|---------|----------|
| `_sed_in_place()` | Cross-platform `sed -i` wrapper | ✅ Yes |
| `_sedrepl_pretty_print()` | Syntax-check and display sed script | ✅ Yes |
| `_sedrepl_divide()` | Split input file into source/data/args components | ✅ Yes |
| `sedrepl()` | Main entry point - sets up tmux environment | N/A |

### Function Call Graph

```
sedrepl() [ENTRY POINT]
    │
    ├─ Embeds functions via 'declare -f' in generated scripts
    │   ├─ _sed_in_place()
    │   └─ _sedrepl_divide()
    │
    ├─ Exports functions for tmux subshells via 'export -f':
    │   ├─ _sed_in_place()
    │   └─ _sedrepl_divide()
    │
    └─ Generates temporary scripts:
        ├─ $runner   → calls _sedrepl_divide() → runs sed
        ├─ $formatter → calls _sedrepl_pretty_print()
        └─ $cleanup  → removes temp files
```

---

## Interface at Each Level

### Level 1: User Interface (Tmux Pane 0)
- **Component**: `$EDITOR ~/.repl.sed` (defaults to `nano`)
- **User actions**: Edit sed script
- **File path**: `$HOME/.repl.sed`
- **Features**: 
  - Supports `#DATA` section for test input
  - Supports `#ARGS` section for sed command-line flags

### Level 2: Runner Interface (Tmux Pane 1)
- **Component**: `entr -c './$runner'`
- **Triggers**: File change events on `~/.repl.sed`
- **Operations**:
  - Clears screen before execution (`-c` flag)
  - Splits input file into source/data/args
  - Executes: `sed $(cat $args) -f $src $data`
  - Prints dimmed info lines for working directory and command

### Level 3: Formatter Interface (Tmux Pane 2)
- **Component**: `entr -c './$formatter'`
- **Triggers**: File change events on temp `$src` file (created by runner)
- **Operations**:
  - Waits 1 second for runner to finish (race condition prevention)
  - Syntax-checks sed script using `sed -n -f $src /dev/null`
  - Displays sed script using `cat` or `bat` for syntax highlighting

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
    ├─ _sedrepl_divide() splits input
    └─ sed $(cat $args) -f $src $data
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
├── sedrepl           # Main script (executable)
├── Makefile          # Build targets
├── Dockerfile        # Docker image definition
├── examples.sed      # Demonstration sed code
├── README.md         # Project documentation
└── demo.gif          # Demo screenshot (optional)
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
- **Clean exit** - resources deleted automatically
