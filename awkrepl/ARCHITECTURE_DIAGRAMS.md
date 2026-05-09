# AWK REPL Architecture Diagrams

This document contains visual representations of the awkrepl architecture, data flow, and system components.

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  tmux Session: awkrepl                                      │   │
│  │  ┌─────────────────┬───────────────────────────────────────┐  │   │
│  │  │   PANE 0        │   PANE 1        │   PANE 2            │  │   │
│  │  │  (Editor)       │  (Runner)       │  (Formatter)        │  │   │
│  │  │                 │                   │                   │  │   │
│  │  │ editor process  │  entr process   │  entr process      │  │   │
│  │  │ ~/.repl.awk     │  $HOME/.repl.awk│  temp $src file     │  │   │
│  │  │                 │                 │                   │  │   │
│  │  └─────────────────┴─────────────────┴───────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        FILE SYSTEM LAYER                            │
│  ┌─────────────────┐   ┌─────────────────────────────────────────┐  │
│  │  ~/.repl.awk    │   │  .awkrepl-* (temp files)              │  │
│  │  - AWK source   │   │  - src: cleaned code                  │  │
│  │  - #DATA section│   │  - data: test input                   │  │
│  │  - #ARGS section│   │  - args: gawk flags                   │  │
│  │                 │   │  - runner: shell script               │  │
│  │                 │   │  - formatter: shell script            │  │
│  │                 │   │  - helpers: AWK library               │  │
│  └─────────────────┘   └─────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     EXECUTION LAYER                                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  gawk (GNU AWK)                                             │   │
│  │  -f ~/.awkrepl-helpers-*  (helpers library)                 │   │
│  │  -f /tmp/awkrepl-src-*    (user code)                      │   │
│  │  /tmp/awkrepl-data-*      (test input)                     │   │
│  │  $(cat /tmp/awkrepl-args-*)  (command-line flags)          │   │
│  │                                                              │   │
│  │  │─────────┬───────────┬───────────┬────────────┐          │   │
│  │            │           │           │            │          │   │
│  ▼            ▼           ▼           ▼            ▼          ▼   │
│  Output     Formatting  Errors    Debug Info    Help          │   │
│  to pane 1  to pane 2                           Functions      │   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        COMPONENT LAYOUT                             │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Main Script (awkrepl)                    │   │
│  │  ┌───────────────────────────────────────────────────────┐  │   │
│  │  │   Local Functions                                    │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐     │  │   │
│  │  │  │ _sed_    │  │ _trim_   │  │ _awkrepl_        │     │  │   │
│  │  │  │ in_place │  │ blanks   │  │   divide         │     │  │   │
│  │  │  └──────────┘  └──────────┘  └──────────────────┘     │  │   │
│  │  │                                                        │  │   │
│  │  │  ┌──────────────────────────────────────┐             │  │   │
│  │  │  │  _awkrepl_pretty_print              │             │  │   │
│  │  │  └──────────────────────────────────────┘             │  │   │
│  │  └───────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  Exported Functions ─────────┘                                      │
│  (for tmux shells)                                                 │
│                              │                                      │
│  ┌───────────────────────────┴─────────────────────────────────┐   │
│  │                   Bash Functions                            │   │
│  │  - _sed_in_place():      sed -i wrapper                    │   │
│  │  - _trim_blanks():       strip leading/trailing blanks     │   │
│  │  - _awkrepl_divide():    split file into components        │   │
│  │  - _awkrepl_pretty_print():pretty-print with optional bat  │   │
│  │  - awkrepl():            main orchestrator                 │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌───────────────────────────┴─────────────────────────────────┐   │
│  │                   File Operations                           │   │
│  │  - mktemp():     create temporary files                    │   │
│  │  - touch():      ensure ~/.repl.awk exists                 │   │
│  │  - mv():         move temp files                           │   │
│  │  - chmod():      make scripts executable                   │   │
│  │  - rm():         cleanup (via $cleanup script)             │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌───────────────────────────┴─────────────────────────────────┐   │
│  │                   External Commands                         │   │
│  │  - tmux:         terminal multiplexer                      │   │
│  │  - gawk:         AWK interpreter                           │   │
│  │  - entr:         file change watcher                       │   │
│  │  - perl:         pattern detection                         │   │
│  │  - sed:          text processing                           │   │
│  │  - echo/printf:  output                                    │   │
│  │  - bat/cat:      optional syntax highlighting              │   │
│  └───────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    USER INPUT (Editor)                              │
│                    Pane 0: nano/vim/emacs                           │
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
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  1. _awkrepl_divide()                                       │   │
│  │     Input: ~/.repl.awk                                      │   │
│  │     ┌───────────────────────────────────────────────────┐   │   │
│  │     │  Split into:                                      │   │   │
│  │     │  - $src  (AWK code, cleaned)                     │   │   │
│  │     │  - $data (test input, from #DATA)                │   │   │
│  │     │  - $args (gawk flags, from #ARGS)                │   │   │
│  │     └───────────────────────────────────────────────────┘   │   │
│  │                                                             │   │
│  │  2. Build gawk command                                      │   │
│  │     gawk $(cat $args) -f $helpers -f $src $data            │   │
│  │                                                             │   │
│  │  3. Execute gawk                                            │   │
│  │     ┌───────────────────────────────────────────────────┐   │   │
│  │     │  gawk:                                            │   │   │
│  │     │  -f helpers (printa, printaa, printerr)          │   │   │
│  │     │  -f src (user code)                              │   │   │
│  │     │  data (test input)                               │   │   │
│  │     └───────────────────────────────────────────────────┘   │   │
│  │                                                             │   │
│  │  4. Output to pane 1 (stdout)                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│  ┌───────────────────────────┴─────────────────────────────────┐   │
│  │                    Side Effect                              │   │
│  │  $src file rewritten (cleaned, auto-wrapped)              │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                              │
│                              ▼ (3. File change detected - re-run)
┌─────────────────────────────────────────────────────────────────────┐
│                    FORMATTER TRIGGERED                              │
│                    entr (pane 2)                                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (4. Execute formatter script)
┌─────────────────────────────────────────────────────────────────────┐
│                    FORMATTER SCRIPT EXECUTION                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  1. sleep 1                                                 │   │
│  │     (wait for runner to finish)                            │   │
│  │                                                             │   │
│  │  2. _awkrepl_pretty_print($src)                            │   │
│  │     Input: $src (cleaned AWK code)                         │   │
│  │                                                             │   │
│  │  3. gawk --pretty-print=- -f $src                          │   │
│  │     (reformats code)                                       │   │
│  │                                                             │   │
│  │  4. Pipe through bat (if available)                        │   │
│  │     (syntax highlighting)                                  │   │
│  │                                                             │   │
│  │  5. Output to pane 2 (stdout)                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Function Call Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                   FUNCTION CALL FLOW                                │
│                                                                     │
│  1. awkrepl "$@"                                                   │
│     ┌────────────────────────────────────────────────────────┐   │
│     │  - Create temp files (7 files)                        │   │
│     │  - Write AWKHELPERS to helpers file                   │   │
│     │  - Generate $runner script                            │   │
│     │  - Generate $formatter script                         │   │
│     │  - Generate $cleanup script                           │   │
│     │  - chmod +x runner, formatter, cleanup                │   │
│     │  - Launch tmux session                                │   │
│     └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    User edits and saves
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Tmux Pane 1 (Runner)                              │
│  entr watch ~/.repl.awk                                            │
│     │                                                              │
│     ▼ (file save)                                                  │
│  $runner script executes                                           │
│     │                                                              │
│     ▼                                                              │
│  _awkrepl_divide()                                                 │
│     │                                                              │
│     ├─ _sed_in_place()  [×3 - remove headers]                      │
│     │                                                              │
│     ├─ _trim_blanks()  [strip blanks]                              │
│     │                                                              │
│     └─ Perl pattern check  [auto-wrap?]                            │
│                                                                     │
│     ▼                                                              │
│  gawk $(cat $args) -f $helpers -f $src $data                      │
│     │                                                              │
│     ▼                                                              │
│  Output to pane 1                                                  │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ (temp $src rewritten)
┌─────────────────────────────────────────────────────────────────────┐
│                   Tmux Pane 2 (Formatter)                           │
│  entr watch $src (temp file)                                       │
│     │                                                              │
│     ▼ (file save)                                                  │
│  $formatter script executes                                        │
│     │                                                              │
│     ▼                                                              │
│  sleep 1                                                           │
│     │                                                              │
│     ▼                                                              │
│  _awkrepl_pretty_print()                                           │
│     │                                                              │
│     ▼                                                              │
│  gawk --pretty-print=- -f $src                                     │
│     │                                                              │
│     ▼                                                              │
│  Output to pane 2 (formatted code)                                 │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ (editor pane exit)
┌─────────────────────────────────────────────────────────────────────┐
│                   CLEANUP ON EXIT                                   │
│  tmux hook: pane-exited[0]                                         │
│     │                                                              │
│     ▼                                                              │
│  $cleanup script executes                                          │
│     │                                                              │
│     ▼                                                              │
│  rm -f $src $data $args $runner $formatter $helpers $cleanup      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Event Loop Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EVEN T-DRIVEN LOOP (entr)                        │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    PANE 1: Runner                            │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  entr: Watch file                                    │   │  │
│  │  │  ~~~~~~~~                                            │   │  │
│  │  │  ┌─┐                                                 │   │  │
│  │  │  │ │  inotify/kqueue API (Linux/BSD)                 │   │  │
│  │  │  │ │  ────► wait for file change event               │   │  │
│  │  │  └─┘                                                 │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  On file event:                                      │   │  │
│  │  │  ~~~~~~~~~~~~                                      │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌────────────────────────────────────────────┐      │   │  │
│  │  │  │  1. Clear screen (-c flag)                 │      │   │  │
│  │  │  │  2. Execute command                        │      │   │  │
│  │  │  │     ./runner                               │      │   │  │
│  │  │  └────────────────────────────────────────────┘      │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  Loop:                                                 │   │  │
│  │  │  ~~~~                                                 │   │  │
│  │  │  Wait ──► Event ──► Execute ──► Wait ──► ...          │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    PANE 2: Formatter                         │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  entr: Watch file                                    │   │  │
│  │  │  ~~~~~~~~                                            │   │  │
│  │  │  ┌─┐                                                 │   │  │
│  │  │  │ │  inotify/kqueue API (Linux/BSD)                 │   │  │
│  │  │  │ │  ────► wait for file change event               │   │  │
│  │  │  └─┘                                                 │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  On file event:                                      │   │  │
│  │  │  ~~~~~~~~~~~~                                      │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌────────────────────────────────────────────┐      │   │  │
│  │  │  │  1. Clear screen (-c flag)                 │      │   │  │
│  │  │  │  2. Sleep 1 (race prevention)              │      │   │  │
│  │  │  │  3. Execute command                        │      │   │  │
│  │  │  │     ./formatter                           │      │   │  │
│  │  │  └────────────────────────────────────────────┘      │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  Loop:                                                 │   │  │
│  │  │  ~~~~                                                 │   │  │
│  │  │  Wait ──► Event ──► Execute ──► Wait ──► ...          │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   INTER-PROCESS COMMUNICATION                │  │
│  │  Entr 1 writes to temp file $src → Entr 2 watches $src      │  │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Layers Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                                │
│                        awkrepl script                               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  User-facing interface:                                     │   │
│  │  - Editor (pane 0)                                          │   │
│  │  - Runner (pane 1)                                          │   │
│  │  - Formatter (pane 2)                                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                               │
│                        tmux session                                 │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Multi-pane layout:                                         │   │
│  │  ┌──────────────────┬───────────────────────────────────┐   │   │
│  │  │   pane 0         │   pane 2                         │   │   │
│  │  │   (editor)       │   (formatter)                    │   │   │
│  │  │                  │                                  │   │   │
│  │  └──────────────────┴───────────────────────────────────┘   │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │                 pane 1 (runner)                      │   │   │
│  │  │  (AWK execution)                                     │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EVENT HANDLING LAYER                             │
│                        entr file watcher                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  inotify (Linux) / kqueue (BSD/macOS)                       │   │
│  │                                                              │   │
│  │  +─────────────+  +─────────────+                           │   │
│  │  │ Runner      │  │ Formatter   │                           │   │
│  │  │ watch       │  │ watch       │                           │   │
│  │  │ ~/.repl.awk │  │ $src file   │                           │   │
│  │  +─────────────+  +─────────────+                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SCRIPT GENERATION LAYER                          │
│                        Generated bash scripts                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  $runner    - AWK execution script                          │   │
│  │  $formatter - Pretty-print script                           │   │
│  │  $cleanup   - Cleanup script                                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA PROCESSING LAYER                            │
│                        AWK execution                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  gawk:                                                      │   │
│  │  -f helpers (AWK library)                                   │   │
│  │  -f src (user code)                                         │   │
│  │  data (test input)                                          │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FILE SYSTEM LAYER                                │
│                        Temporary files                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Temp files (.awkrepl-*):                                   │   │
│  │  - src  (cleaned AWK code)                                  │   │
│  │  - data (test input)                                        │   │
│  │  - args (gawk flags)                                        │   │
│  │  - runner (execution script)                                │   │
│  │  - formatter (format script)                                │   │
│  │  - helpers (AWK library)                                    │   │
│  │  - cleanup (cleanup script)                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## State Transition Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STATE TRANSITIONS                                │
│                                                                     │
│  Initial State (awkrepl command)                                   │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Setup Phase                                                │   │
│  │  - Create temp files (7)                                    │   │
│  │  - Write AWKHELPERS                                         │   │
│  │  - Generate runner script                                   │   │
│  │  - Generate formatter script                                │   │
│  │  - Generate cleanup script                                  │   │
│  │  - chmod scripts executable                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  tmux Session Started                                       │   │
│  │  - Pane 0: Editor                                           │   │
│  │  - Pane 1: entr watch ~/.repl.awk                           │   │
│  │  - Pane 2: entr watch $src                                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼ (User saves ~/.repl.awk)                                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Execution Loop (runs until editor exit)                    │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ 1. File save detected (entr #1)                      │   │   │
│  │  │                                                      │   │   │
│  │  │ 2. Execute $runner                                   │   │   │
│  │  │  - _awkrepl_divide()                                 │   │   │
│  │  │  - gawk -f $helpers -f $src $data                    │   │   │
│  │  │  - Output pane 1                                     │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ 3. $src rewritten (side effect)                      │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ 4. File save detected (entr #2)                      │   │   │
│  │  │                                                      │   │   │
│  │  │ 5. Execute $formatter                                │   │   │
│  │  │  - sleep 1                                           │   │   │
│  │  │  - _awkrepl_pretty_print()                           │   │   │
│  │  │  - Output pane 2                                     │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │ Loop (Step 1-5 repeats on save)                      │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼ (Editor pane exits)                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Cleanup Phase                                              │   │
│  │  $cleanup runs (via tmux hook)                              │   │
│  │  rm -f all temp files                                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Session Terminated                                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Architectural Patterns

### 1. Multi-Pane Terminal Layout
```
┌────────────────────────────────────────────────────────────┐
│ pane 0 (editor)                    pane 2 (formatter)     │
│ ~/.repl.awk                        $src (temp)            │
│ $EDITOR                            _awkrepl_pretty_print  │
│                                                    │      │
├────────────────────────────────────────────────────────────┤
│                    pane 1 (runner)                         │
│                    ~/.repl.awk                             │
│                    _awkrepl_divide                         │
│                    gawk -f helpers -f src data            │
└────────────────────────────────────────────────────────────┘
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
Editor pane exit → tmux hook → cleanup script → rm temp files
```

---

This architecture provides a responsive, interactive development environment where:
- **One save** triggers **two independent reactions** (execution and formatting)
- **No polling** - uses kernel file events via `entr`
- **Self-contained** - scripts embed functions via `declare -f`
- **Clean exit** - resources deleted automatically
