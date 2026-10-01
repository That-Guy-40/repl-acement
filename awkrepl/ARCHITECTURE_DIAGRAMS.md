# AWK REPL Architecture Diagrams

This document contains visual representations of the awkrepl architecture, data flow, and system components.

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                            │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  tmux window: awkrepl                                         │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │   PANE 0 (Editor, top)                                  │  │  │
│  │  │   editor process: $EDITOR ~/.repl.awk                   │  │  │
│  │  ├────────────────────────────┬────────────────────────────┤  │  │
│  │  │   PANE 1 (Runner,          │   PANE 2 (Formatter,       │  │  │
│  │  │           bottom-left)     │           bottom-right)    │  │  │
│  │  │   entr process             │   entr process             │  │  │
│  │  │   watches ~/.repl.awk      │   watches temp $src file   │  │  │
│  │  └────────────────────────────┴────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        FILE SYSTEM LAYER                            │
│  ┌─────────────────┐   ┌─────────────────────────────────────────┐  │
│  │  ~/.repl.awk    │   │  ${TMPDIR:-/tmp}/awkrepl-* (temp files) │  │
│  │  - AWK source   │   │  - src: cleaned code                    │  │
│  │  - #DATA section│   │  - data: test input                     │  │
│  │  - #ARGS section│   │  - args: gawk flags                     │  │
│  │                 │   │  - run: runner shell script             │  │
│  │                 │   │  - fmt: formatter shell script          │  │
│  │                 │   │  - helpers: AWK library                 │  │
│  │                 │   │  - cleanup: cleanup shell script        │  │
│  └─────────────────┘   └─────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     EXECUTION LAYER                                 │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Runner (pane 1):                                             │  │
│  │    gawk "${_gawk_args[@]}"  (#ARGS, via _repl_parse_args)     │  │
│  │      -f ${TMPDIR:-/tmp}/awkrepl-helpers-*  (helpers library)  │  │
│  │      -f ${TMPDIR:-/tmp}/awkrepl-src-*      (user code)        │  │
│  │      ${TMPDIR:-/tmp}/awkrepl-data-*        (test input)       │  │
│  │    → program output and gawk errors in pane 1                 │  │
│  │                                                               │  │
│  │  Formatter (pane 2):                                          │  │
│  │    gawk --pretty-print=- -f ${TMPDIR:-/tmp}/awkrepl-src-*     │  │
│  │      | bat/batcat (if installed)                              │  │
│  │    → formatted code (or ERROR + raw source) in pane 2         │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        COMPONENT LAYOUT                             │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Main Script (awkrepl)                      │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │   Global: AWKHELPERS (printerr, printa, printaa)        │  │  │
│  │  │                                                         │  │  │
│  │  │   Helper Functions                                      │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐       │  │  │
│  │  │  │ _sed_    │  │ _trim_   │  │ _awkrepl_        │       │  │  │
│  │  │  │ in_place │  │ blanks   │  │   divide         │       │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────────────┘       │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌───────────────────────┐  ┌──────────────────┐        │  │  │
│  │  │  │ _awkrepl_pretty_print │  │ _repl_parse_args │        │  │  │
│  │  │  └───────────────────────┘  └──────────────────┘        │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌────────────────┐  ┌─────────┐                        │  │  │
│  │  │  │ _awkrepl_setup │  │ awkrepl │                        │  │  │
│  │  │  └────────────────┘  └─────────┘                        │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│  export -f: _sed_in_place, _awkrepl_divide,                         │
│             _awkrepl_pretty_print, _repl_parse_args                 │
│  declare -f (embedded in generated scripts):                        │
│    $runner:    _sed_in_place, _trim_blanks, _awkrepl_divide,        │
│                _repl_parse_args                                     │
│    $formatter: _awkrepl_pretty_print                                │
│                              │                                      │
│  ┌───────────────────────────┴───────────────────────────────────┐  │
│  │                   Bash Functions                              │  │
│  │  - _sed_in_place():         sed -i wrapper (GNU/BSD)          │  │
│  │  - _trim_blanks():          strip leading/trailing blank lines│  │
│  │  - _awkrepl_pretty_print(): pretty-print, optional bat/batcat │  │
│  │  - _awkrepl_divide():       split file into src/data/args     │  │
│  │  - _repl_parse_args():      #ARGS → NUL-separated tokens      │  │
│  │  - _awkrepl_setup():        temp files + generated scripts;   │  │
│  │                             sets REPL_* / REPL_Q_* globals    │  │
│  │  - awkrepl():               main orchestrator (tmux launch)   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────┴───────────────────────────────────┐  │
│  │                   File Operations                             │  │
│  │  - mktemp:       create temp files under ${TMPDIR:-/tmp}      │  │
│  │  - touch:        ensure ~/.repl.awk exists                    │  │
│  │  - mv:           replace $src after _trim_blanks              │  │
│  │  - chmod:        make scripts executable                      │  │
│  │  - rm:           cleanup ($cleanup script + backstop)         │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────┴───────────────────────────────────┐  │
│  │                   External Commands                           │  │
│  │  - tmux:         terminal multiplexer                         │  │
│  │  - gawk:         AWK interpreter and pretty-printer           │  │
│  │  - entr:         file change watcher                          │  │
│  │  - perl:         auto-wrap pattern detection                  │  │
│  │  - sed:          text processing                              │  │
│  │  - xargs:        #ARGS tokenizing (quotes, no globbing)       │  │
│  │  - tac / tail -r: line reversal in _trim_blanks               │  │
│  │  - tput:         dim header color in runner                   │  │
│  │  - bat/batcat:   optional syntax highlighting (else cat)      │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    USER INPUT (Editor)                              │
│                    Pane 0: ${EDITOR:-nano}                          │
│                    File: ~/.repl.awk                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (1. File save event)
┌─────────────────────────────────────────────────────────────────────┐
│                    FILE CHANGE DETECTED                             │
│                    entr (pane 1)                                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (2. Execute runner script)
┌─────────────────────────────────────────────────────────────────────┐
│                    RUNNER SCRIPT EXECUTION                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  1. _awkrepl_divide()                                         │  │
│  │     Input: ~/.repl.awk                                        │  │
│  │     ┌─────────────────────────────────────────────────────┐   │  │
│  │     │  Split into:                                        │   │  │
│  │     │  - $src  (AWK code, cleaned, maybe auto-wrapped)    │   │  │
│  │     │  - $data (test input, after #DATA)                  │   │  │
│  │     │  - $args (gawk flags, from #ARGS)                   │   │  │
│  │     └─────────────────────────────────────────────────────┘   │  │
│  │                                                               │  │
│  │  2. Parse args into an array                                  │  │
│  │     _repl_parse_args $args → _gawk_args=( ... )               │  │
│  │     print "# work dir:" and "# command:" header lines         │  │
│  │                                                               │  │
│  │  3. Execute gawk                                              │  │
│  │     ┌─────────────────────────────────────────────────────┐   │  │
│  │     │  gawk "${_gawk_args[@]}"                            │   │  │
│  │     │  -f helpers (printerr, printa, printaa)             │   │  │
│  │     │  -f src (user code)                                 │   │  │
│  │     │  data (test input)                                  │   │  │
│  │     └─────────────────────────────────────────────────────┘   │  │
│  │                                                               │  │
│  │  4. Output to pane 1 (stdout/stderr)                          │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────┴───────────────────────────────────┐  │
│  │                    Side Effect                                │  │
│  │  $src file rewritten (cleaned, auto-wrapped)                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (3. File change detected)
┌─────────────────────────────────────────────────────────────────────┐
│                    FORMATTER TRIGGERED                              │
│                    entr (pane 2)                                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (4. Execute formatter script)
┌─────────────────────────────────────────────────────────────────────┐
│                    FORMATTER SCRIPT EXECUTION                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  1. sleep 1                                                   │  │
│  │     (let the runner finish rewriting $src)                    │  │
│  │                                                               │  │
│  │  2. _awkrepl_pretty_print $src                                │  │
│  │     Input: $src (cleaned AWK code)                            │  │
│  │                                                               │  │
│  │  3. gawk --pretty-print=- -f $src                             │  │
│  │     (reformats code)                                          │  │
│  │                                                               │  │
│  │  4. Pipe through bat/batcat (if available, else cat)          │  │
│  │     (syntax highlighting; on parse error, print ERROR and     │  │
│  │      the raw source instead)                                  │  │
│  │                                                               │  │
│  │  5. Output to pane 2 (stdout)                                 │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Function Call Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                   FUNCTION CALL FLOW                                │
│                                                                     │
│  1. awkrepl  (runs only when the script is executed, not sourced;   │
│               ignores arguments — the file is always ~/.repl.awk)   │
│     ┌───────────────────────────────────────────────────────────┐   │
│     │  - touch ~/.repl.awk if missing                           │   │
│     │  - _awkrepl_setup ~/.repl.awk                             │   │
│     │      - mktemp 7 files in ${TMPDIR:-/tmp}/awkrepl-*        │   │
│     │      - Write AWKHELPERS to helpers file                   │   │
│     │      - Generate $runner, $formatter, $cleanup scripts     │   │
│     │      - chmod a+x runner, formatter, cleanup               │   │
│     │      - Set REPL_* and %q-quoted REPL_Q_* globals          │   │
│     │  - Launch tmux (new session, or new window if nested)     │   │
│     │  - When not nested: after tmux exits, rm -f temp files    │   │
│     └───────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    User edits and saves
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Tmux Pane 1 (Runner)                              │
│  entr watch ~/.repl.awk                                             │
│     │                                                               │
│     ▼ (startup, then each file save)                                │
│  $runner script executes                                            │
│     │                                                               │
│     ▼                                                               │
│  _awkrepl_divide()                                                  │
│     │                                                               │
│     ├─ sed -n ... w  [write $args, $src, $data]                     │
│     │                                                               │
│     ├─ _sed_in_place()  [remove #DATA/#ARGS headers]                │
│     │                                                               │
│     ├─ _trim_blanks()  [strip leading/trailing blank lines]         │
│     │                                                               │
│     ├─ _sed_in_place()  [remove comment and blank lines]            │
│     │                                                               │
│     └─ Perl pattern check → _sed_in_place() [auto-wrap if needed]   │
│     │                                                               │
│     ▼                                                               │
│  _repl_parse_args $args → _gawk_args                                │
│     │                                                               │
│     ▼                                                               │
│  gawk "${_gawk_args[@]}" -f $helpers -f $src $data                  │
│     │                                                               │
│     ▼                                                               │
│  Output to pane 1                                                   │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ (temp $src rewritten)
┌─────────────────────────────────────────────────────────────────────┐
│                   Tmux Pane 2 (Formatter)                           │
│  entr watch $src (temp file)                                        │
│     │                                                               │
│     ▼ (startup, then each change to $src)                           │
│  $formatter script executes                                         │
│     │                                                               │
│     ▼                                                               │
│  sleep 1                                                            │
│     │                                                               │
│     ▼                                                               │
│  _awkrepl_pretty_print()                                            │
│     │                                                               │
│     ▼                                                               │
│  gawk --pretty-print=- -f $src | bat/batcat (or cat)                │
│     │                                                               │
│     ▼                                                               │
│  Output to pane 2 (formatted code)                                  │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ (a pane exits, e.g. the editor)
┌─────────────────────────────────────────────────────────────────────┐
│                   CLEANUP ON EXIT                                   │
│  tmux session hooks: pane-exited[0], pane-exited[1]                 │
│  ([0]/[1] are hook-array slots; both run when ANY pane exits)       │
│     │                                                               │
│     ▼                                                               │
│  [0] run-shell $cleanup                                             │
│        rm -f $src $data $args $runner $formatter $helpers $cleanup  │
│  [1] kill-window                                                    │
│     │                                                               │
│     ▼                                                               │
│  Backstop (not nested in tmux): once 'tmux new-session' returns     │
│  and the named session is gone, awkrepl() rm -f's the same files    │
│  (a detach also returns, but the session lives on: no rm)           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Event Loop Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT-DRIVEN LOOP (entr)                         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    PANE 1: Runner                            │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  entr: Watch file (~/.repl.awk)                      │    │   │
│  │  │  ~~~~~~~~                                            │    │   │
│  │  │  ┌─┐                                                 │    │   │
│  │  │  │ │  inotify/kqueue API (Linux/BSD)                 │    │   │
│  │  │  │ │  ────► wait for file change event               │    │   │
│  │  │  └─┘                                                 │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  On startup and on each file event:                  │    │   │
│  │  │  ~~~~~~~~~~~~                                        │    │   │
│  │  │                                                      │    │   │
│  │  │  ┌────────────────────────────────────────────┐      │    │   │
│  │  │  │  1. Clear screen (-c flag)                 │      │    │   │
│  │  │  │  2. Execute command                        │      │    │   │
│  │  │  │     $runner (absolute temp path)           │      │    │   │
│  │  │  └────────────────────────────────────────────┘      │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  Loop:                                               │    │   │
│  │  │  ~~~~                                                │    │   │
│  │  │  Wait ──► Event ──► Execute ──► Wait ──► ...         │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    PANE 2: Formatter                         │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  entr: Watch file ($src)                             │    │   │
│  │  │  ~~~~~~~~                                            │    │   │
│  │  │  ┌─┐                                                 │    │   │
│  │  │  │ │  inotify/kqueue API (Linux/BSD)                 │    │   │
│  │  │  │ │  ────► wait for file change event               │    │   │
│  │  │  └─┘                                                 │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  On startup and on each file event:                  │    │   │
│  │  │  ~~~~~~~~~~~~                                        │    │   │
│  │  │                                                      │    │   │
│  │  │  ┌────────────────────────────────────────────┐      │    │   │
│  │  │  │  1. Clear screen (-c flag)                 │      │    │   │
│  │  │  │  2. Execute command                        │      │    │   │
│  │  │  │     $formatter (absolute temp path),       │      │    │   │
│  │  │  │     which first does sleep 1               │      │    │   │
│  │  │  └────────────────────────────────────────────┘      │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  Loop:                                               │    │   │
│  │  │  ~~~~                                                │    │   │
│  │  │  Wait ──► Event ──► Execute ──► Wait ──► ...         │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   INTER-PROCESS COMMUNICATION                │   │
│  │  Runner (entr 1) rewrites temp file $src → entr 2 watches it │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Layers Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                                │
│                        awkrepl script                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  User-facing interface:                                       │  │
│  │  - Editor (pane 0)                                            │  │
│  │  - Runner (pane 1)                                            │  │
│  │  - Formatter (pane 2)                                         │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                               │
│                tmux session (or window, if nested)                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Multi-pane layout:                                           │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                 pane 0 (editor)                         │  │  │
│  │  │                                                         │  │  │
│  │  ├────────────────────────────┬────────────────────────────┤  │  │
│  │  │   pane 1 (runner)          │   pane 2 (formatter)       │  │  │
│  │  │   (AWK execution)          │   (pretty-print)           │  │  │
│  │  └────────────────────────────┴────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT HANDLING LAYER                             │
│                        entr file watcher                            │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  inotify (Linux) / kqueue (BSD/macOS)                         │  │
│  │                                                               │  │
│  │  +─────────────+  +─────────────+                             │  │
│  │  │ Runner      │  │ Formatter   │                             │  │
│  │  │ watch       │  │ watch       │                             │  │
│  │  │ ~/.repl.awk │  │ $src file   │                             │  │
│  │  +─────────────+  +─────────────+                             │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SCRIPT GENERATION LAYER                          │
│              Generated bash scripts (by _awkrepl_setup)             │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  $runner    - AWK execution script                            │  │
│  │  $formatter - Pretty-print script                             │  │
│  │  $cleanup   - Cleanup script                                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA PROCESSING LAYER                            │
│                        AWK execution                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  gawk:                                                        │  │
│  │  #ARGS tokens (via _repl_parse_args)                          │  │
│  │  -f helpers (AWK library)                                     │  │
│  │  -f src (user code)                                           │  │
│  │  data (test input)                                            │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FILE SYSTEM LAYER                                │
│                        Temporary files                              │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Temp files (${TMPDIR:-/tmp}/awkrepl-<kind>-XXXXXX):          │  │
│  │  - src     (cleaned AWK code)                                 │  │
│  │  - data    (test input)                                       │  │
│  │  - args    (gawk flags)                                       │  │
│  │  - run     (runner/execution script)                          │  │
│  │  - fmt     (formatter script)                                 │  │
│  │  - helpers (AWK library)                                      │  │
│  │  - cleanup (cleanup script)                                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## State Transition Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STATE TRANSITIONS                                │
│                                                                     │
│  Initial State (awkrepl command)                                    │
│         │                                                           │
│         ▼                                                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Setup Phase (_awkrepl_setup)                                 │  │
│  │  - Create temp files (7) in ${TMPDIR:-/tmp}                   │  │
│  │  - Write AWKHELPERS                                           │  │
│  │  - Generate runner script                                     │  │
│  │  - Generate formatter script                                  │  │
│  │  - Generate cleanup script                                    │  │
│  │  - chmod scripts executable                                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│         │                                                           │
│         ▼                                                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  tmux Session (or nested window) Started                      │  │
│  │  - Pane 0: Editor                                             │  │
│  │  - Pane 1: entr watch ~/.repl.awk (runs $runner once)         │  │
│  │  - Pane 2: entr watch $src (runs $formatter once)             │  │
│  └───────────────────────────────────────────────────────────────┘  │
│         │                                                           │
│         ▼ (User saves ~/.repl.awk)                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Execution Loop (runs until a pane exits)                     │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │ 1. File save detected (entr #1)                         │  │  │
│  │  │                                                         │  │  │
│  │  │ 2. Execute $runner                                      │  │  │
│  │  │  - _awkrepl_divide()                                    │  │  │
│  │  │  - _repl_parse_args()                                   │  │  │
│  │  │  - gawk ARGS... -f $helpers -f $src $data               │  │  │
│  │  │  - Output pane 1                                        │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │ 3. $src rewritten (side effect)                         │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │ 4. File change detected (entr #2)                       │  │  │
│  │  │                                                         │  │  │
│  │  │ 5. Execute $formatter                                   │  │  │
│  │  │  - sleep 1                                              │  │  │
│  │  │  - _awkrepl_pretty_print()                              │  │  │
│  │  │  - Output pane 2                                        │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │ Loop (Step 1-5 repeats on save)                         │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│         │                                                           │
│         ▼ (Editor pane exits — any pane exit fires the hooks)       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Cleanup Phase                                                │  │
│  │  $cleanup runs (tmux hook pane-exited[0]): rm -f temp files   │  │
│  │  kill-window (tmux hook pane-exited[1])                       │  │
│  │  Backstop when not nested: awkrepl() rm -f's temp files       │  │
│  │  once 'tmux new-session' returns and the session is gone      │  │
│  │  (not on a detach: the detached session keeps its files)      │  │
│  └───────────────────────────────────────────────────────────────┘  │
│         │                                                           │
│         ▼                                                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Window closed (session ends if it was the only window)       │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Architectural Patterns

### 1. Multi-Pane Terminal Layout
```
┌────────────────────────────────────────────────────────────┐
│ pane 0 (editor)                                            │
│ $EDITOR ~/.repl.awk                                        │
│                                                            │
├─────────────────────────────┬──────────────────────────────┤
│ pane 1 (runner)             │ pane 2 (formatter)           │
│ watches ~/.repl.awk         │ watches $src (temp)          │
│ _awkrepl_divide             │ sleep 1                      │
│ gawk -f helpers -f src data │ _awkrepl_pretty_print        │
└─────────────────────────────┴──────────────────────────────┘
```

### 2. Reactive Event Loop
```
File save → entr detects → Execute command → Loop
```

### 3. File as Inter-Process Communication
```
Runner → writes $src → Formatter watches $src → reads $src
```

### 4. Cleanup on Exit
```
Pane exit (e.g. editor) → tmux hooks → cleanup script + kill-window → rm temp files
Not nested in tmux: 'tmux new-session' returns and the named session is gone → awkrepl() backstop rm -f
Detach (C-b d): 'tmux new-session' returns but the session lives on → no rm; reattach later
```

---

This architecture provides a responsive, interactive development environment where:
- **One save** triggers **two independent reactions** (execution and formatting)
- **No polling** - uses kernel file events via `entr`
- **Self-contained scripts** - generated scripts embed the functions they need via `declare -f`
- **Clean exit** - temp files deleted by the tmux hook, with a backstop `rm -f` when not nested in tmux and the session has really ended (a detach leaves it running)
