Manual testing guide for repl-acement
=====================================

This is a hands-on test plan for the seven REPLs (`awkrepl`, `sedrepl`,
`jqrepl`, `yqrepl`, `mlrrepl`, `perlrepl`, `workoutrepl`). It covers what the automated
suites cannot see: what a person actually experiences in a real terminal,
with a real editor, in their own tmux session.

What is already automated (run it first, don't repeat it by hand):

| Suite | Command | Covers |
|-------|---------|--------|
| per-REPL smoke + integration | `make unit` | `#DATA`/`#ARGS` splitting, header matching, quoting, auto-wrap, comment handling, the editor-pane wrapper, Makefile targets. Sources the scripts; never opens a UI. |
| end-to-end live UI | `make e2e` | launches each REPL in a scripted terminal, checks live reload, detach/reattach, nested tmux cleanup. Replaces the editor with a no-op keep-alive. |

What this guide adds: a real `$EDITOR` in the top pane, your real tmux
config and keybindings, screen layout and readability, syntax highlighting,
the quit/cleanup paths as a user triggers them, Docker images, and a few
cross-platform spots (BSD sed, macOS) that CI on Linux can't exercise.

How to record results
---------------------

Use three verdicts, never two:

- **PASS**: you observed the expected result.
- **FAIL**: you observed something else. Write down what you saw, verbatim
  if it's text, and the versions from the preflight table.
- **UNKNOWN**: you couldn't run the step (missing tool, no Docker, wrong
  OS). An unchecked row is not a pass. Say why it was skipped.

A run where every row passes should make you suspicious. Section 14 lists
rows that are expected to FAIL or be UNKNOWN on a given setup; if none of
them did, check that you were really running the code under test (e.g. the
`awkrepl` on your `PATH` may be an older copy, not `./awkrepl/awkrepl`).

Copy the results table from section 15 into your notes and fill it in.

1. Preflight
------------

### 1.1 Back up your scratch files

Every REPL edits a file in your home directory and the tests below
overwrite them. Move any you care about aside first:

```bash
ls -la ~/.repl.awk ~/.repl.sed ~/.repl.jq ~/.repl.yq ~/.repl.mlr ~/.repl.pl 2>/dev/null
mkdir -p ~/repl-backup && cp ~/.repl.* ~/repl-backup/ 2>/dev/null
```

### 1.2 Record the environment

Fill in this table; every FAIL report needs it.

```bash
for t in bash tmux entr gawk sed jq yq mlr perl bat batcat xargs; do
  printf '%-8s ' "$t"
  command -v "$t" >/dev/null 2>&1 && "$t" --version 2>&1 | head -1 || echo MISSING
done
echo "EDITOR=${EDITOR:-<unset>}  TMUX=${TMUX:-<unset>}  TMPDIR=${TMPDIR:-<unset>}  $(uname -s)"
```

| Item | Value |
|------|-------|
| OS / kernel | |
| bash | |
| tmux | |
| entr | |
| gawk / sed / jq / yq / mlr / perl | |
| bat or batcat | |
| `$EDITOR` | |
| running inside tmux already? | |

`yq --version` must mention `mikefarah` for `yqrepl` to launch at all. See
section 14 if it is a Go yq whose version string predates that marker.

### 1.3 Run the automated suites and note the baseline

```bash
make unit
make e2e
```

Record which subprojects passed. Manual testing of a REPL whose unit suite
fails is still worth doing, but note the baseline so a manual FAIL isn't
mistaken for a new finding.

### 1.4 Run from the checkout, not from `PATH`

Throughout, invoke the scripts by path, so you know what you are testing:

```bash
cd <repo>
./awkrepl/awkrepl
./sedrepl/sedrepl
# etc.
```

If you also have a copy installed in `~/bin`, note which one each test
used.

2. Launch, layout and quit (run once per REPL)
----------------------------------------------

Do this block seven times, once per REPL, from a plain shell (not inside
tmux). Where the expected text differs by tool, the table after the steps
says how.

**Steps**

1. Run the REPL (e.g. `./awkrepl/awkrepl`). Give it 2 seconds.
2. Look at the layout.
3. Note the session name: in another terminal, `tmux ls`.
4. Save the file in the editor without changing it (`:w` in vim, `C-o
   Enter` in nano).
5. Quit the editor (`:q` in vim, `C-x` in nano).

**Expected**

- Step 1: a new tmux session opens. Three panes: editor across the top,
  output bottom-left, source bottom-right. The cursor is in the editor,
  which has `~/.repl.<ext>` open (the file is created empty if it did not
  exist).
- Step 2: the window's name is the tool's name (`awkrepl`, `sedrepl`, …).
  With an empty file, `awkrepl` and `sedrepl` show a dimmed
  `# work dir: <your cwd>` line and a dimmed `# command: …` line and
  nothing else; `jqrepl`, `yqrepl`, `mlrrepl` and `perlrepl` run nothing
  for an empty program, so their output pane is blank. Once there is a
  program (section 3), every REPL shows the two dimmed lines, and every
  REPL except `awkrepl` echoes the source below them before the tool's
  output. The bottom-right pane shows the source about a second after the
  left one updates; empty source shows nothing.
- Step 3: `tmux ls` lists a session named `<tool>repl-<pid>`, e.g.
  `awkrepl-48213`.
- Step 4: the bottom-left pane clears and redraws (entr clears the screen
  before each run). Nothing else changes.
- Step 5: the whole window closes, the tmux session ends, and you are back
  at the shell prompt you launched from. `tmux ls` no longer lists the
  session. `ls ${TMPDIR:-/tmp}/<tool>repl-*` finds nothing.

| REPL | file | `# command:` line starts with | source echoed in output pane? |
|------|------|-------------------------------|------------------------------|
| awkrepl | `~/.repl.awk` | `gawk  -f …/awkrepl-helpers-… -f …/awkrepl-src-… …/awkrepl-data-…` | no (bottom-right shows gawk's pretty-print instead) |
| sedrepl | `~/.repl.sed` | `sed  -f …/sedrepl-src-… …/sedrepl-data-…` | yes |
| jqrepl | `~/.repl.jq` | `jq -n  -f …/jqrepl-src-…` when there is no `#DATA` | yes |
| yqrepl | `~/.repl.yq` | `yq eval --null-input <expr>` when there is no `#DATA` | yes |
| mlrrepl | `~/.repl.mlr` | `mlr --csv put -f …` (format flag varies, section 7) | yes |
| perlrepl | `~/.repl.pl` | `perl …/perlrepl-src-…` (with `-n` inserted when auto-detected, section 8) | yes |

Note: in `jqrepl`, `yqrepl`, `mlrrepl` and `perlrepl` a file that is empty
or only comments and blank lines runs nothing at all, so the output pane
stays blank, without even the header lines. That is by design.

3. Live reload with a real editor
---------------------------------

Automated tests rewrite the file from outside. This checks that your
editor's actual save mechanism triggers `entr`. Some editors write a new
file and rename it over the old one, which can confuse file watchers.

Run with `awkrepl`, then repeat step 3 with each editor you use.

**Steps**

1. Launch `./awkrepl/awkrepl`, paste the examples file into the editor
   (`cat awkrepl/examples.awk` into it, or `:r awkrepl/examples.awk` in
   vim), save.
2. Watch both bottom panes.
3. Change the active line `print` to `print $4`, save.
4. Make a second edit within one second of the first (e.g. change `$4` to
   `$1`, save immediately).
5. Repeat step 3 with `EDITOR=nano`, `EDITOR=vim`, and your own editor
   (`EDITOR="code -w"` or `EDITOR="emacsclient -t"` if you use them).

**Expected**

- Step 2: the output pane shows the nine data rows unchanged (the active
  example is a bare `print`). About a second later the right pane shows
  the pretty-printed program, which `gawk` has reformatted to
  `{ print }` on three lines, with the comments and blank lines gone.
- Step 3: within a second the output pane shows only the `rs…` IDs
  column. The right pane follows about a second later with `print $4`.
- Step 4: the final state matches the final file. (Intermediate states may
  or may not flash by. What matters is that the last save wins and nothing
  is stuck showing the earlier edit.)
- Step 5: identical behavior for each editor. For `vim`, confirm the
  default `backupcopy` setting still triggers a reload. For a GUI editor
  with `-w`, the pane shows nothing but the window waits, and closing the
  file in the GUI quits the REPL as in section 2 step 5.

4. Syntax errors
----------------

The REPL must show the tool's own error and not crash, hang, or close.

**Steps** (for each REPL, replace the program with the broken one, save)

| REPL | broken program | `#DATA` |
|------|----------------|---------|
| awkrepl | `{ print $1` | `a b` |
| sedrepl | `s/a/b` | `a` |
| jqrepl | `.[ ` | `[1]` |
| yqrepl | `.[ ` | `- 1` |
| mlrrepl | `$x = ;` | `a,b` |
| perlrepl | `print "unterminated;` | `x` |

**Expected**

- The output pane shows the tool's error message (e.g. gawk's
  `source files / command-line arguments must contain complete functions
  or rules`, sed's ``unterminated `s' command``).
- `awkrepl`'s right pane shows the gawk error, then `ERROR parsing AWK
  source; input was:` followed by your source as written.
- `sedrepl`'s right pane shows `ERROR parsing sed script; input was:`, the
  sed error, a `---` line, then your source.
- The other four show the source unchanged in the right pane (there is no
  separate syntax check for them).
- Fix the program and save: the error goes away on the next run. The
  panes never close on an error.

5. `#DATA` and `#ARGS` headers in the live UI
---------------------------------------------

The unit suites check every variant of these headers in detail. Manually,
do a quick sweep of one representative file per REPL so you see the
header handling and the `#ARGS` line end-to-end, and then the quoting
warning, which is the one piece of text a user has to notice.

### 5.1 `#ARGS` in use

| REPL | program | expected output pane |
|------|---------|---------------------|
| awkrepl | `#ARGS -F,` then `{ print $2 }` over data `a,b,c` | `b`; the command line shows `gawk -F, -f …` |
| sedrepl | `#args: -n` then `2p` over three data lines | only line 2; command line `sed -n -f …` |
| jqrepl | `#ARGS -r` then `.[]` over `["x","y"]` | `x` and `y` without quotes |
| yqrepl | `#ARGS -o json` then `.` over `a: 1` (older Go yq builds spell it `#ARGS -j`) | `{"a": 1}`; command line `yq eval <expr> -o json …` |
| mlrrepl | `#ARGS --icsv --ojson` then `$c = $a . $b;` over `a,b` / `1,2` | a JSON record; auto-detection is off because `#ARGS` has options |
| perlrepl | `#ARGS -l` then `print length` over `hello` | `5` on its own line |

### 5.2 Lookalike comments do nothing

In `awkrepl` with the examples file loaded, add these lines above `#DATA`
and save:

```
# Database of SNPs
# data comes from dbSNP
# Args are cool
```

**Expected**: output is unchanged. The data section still starts at the
real `#DATA` line, and no arguments are added to the `gawk` command line.

### 5.3 Unmatched quote warning

In `awkrepl`:

```
#ARGS -v msg=it's
BEGIN { print msg }
```

**Expected**: the output pane shows, above the dimmed header lines:

```
warning: #ARGS has an unmatched quote; splitting it on whitespace instead
```

and then `it's` as the program output (the quote character was kept as
typed). Repeat in one other REPL (e.g. `#ARGS -r` with a stray `'` on the
same line in `jqrepl`) to confirm the warning is shared.

### 5.4 Globs stay literal

`#ARGS -v pat=*` in `awkrepl` with `BEGIN { print pat }`: output is a
single `*`, not a listing of your working directory. Check the command line
in the pane shows `-v pat=*` and nothing was expanded.

### 5.5 `#DATA` on line 1 and after `#DATA`

- A file whose first line is `#DATA` followed by rows (the program is
  empty): `awkrepl` shows the two header lines and no output (gawk with
  no rules prints nothing); `sedrepl` shows the headers and then every
  data row unchanged (an empty sed script is a pass-through); `jqrepl`,
  `yqrepl`, `mlrrepl` and `perlrepl` leave the pane blank (they run
  nothing for an empty program).
- An `#ARGS -n` line placed after `#DATA` in `sedrepl`: it is printed as a
  data row and `-n` is not applied.

6. awkrepl specifics
--------------------

### 6.1 Auto-wrap

Each program on its own, without `#DATA` unless stated. Save and read the
right pane (the wrapped program) and the left pane.

| program | `#DATA`? | right pane | left pane |
|---------|----------|------------|-----------|
| `print "ans=" 6 * 7` | no | `END { print "ans=" 6 * 7 }` reformatted | `ans=42` |
| `x = 3; print x` | no | `END { … }` | `3` |
| `n = split("a b c", arr); printa(arr)` | no | `END { … }` | `length(noname)==3` then `noname[1]=a; noname[2]=b; noname[3]=c` |
| `print $1` | `hello world` | `{ print $1 }` | `hello` |
| `NR > 1` | three lines | `NR > 1` unwrapped (implicit print) | lines 2 and 3 |
| `!seen[$1]++` | `a` / `a` / `b` | unwrapped | `a` then `b` |
| `$NF > 3` | `1 2` / `5 6` | unwrapped | `5 6` |
| `BEGIN { print "x" }` | no | unchanged | `x` |
| `function f() { return 1 } END { print f() }` | no | unchanged | `1` |

### 6.2 Helpers

`printa`, `printaa` and `printerr` are always available (they come from the
`-f …/awkrepl-helpers-…` file on the command line). `BEGIN { printerr("boom") }`
prints `ERROR: boom` in the output pane (via stderr).

### 6.3 Pretty-print and highlighting

With `bat` (or `batcat`) on `PATH`, the right pane is colored. Remove it
from `PATH` for one run:

```bash
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$(dirname "$(command -v bat || command -v batcat)")" | paste -sd:) ./awkrepl/awkrepl
```

**Expected**: the right pane is plain monochrome but shows the same
pretty-printed text. `sedrepl`'s right pane, which highlights as AWK since
bat has no sed syntax, must not print `[bat error]: unknown syntax` in
either case.

7. mlrrepl specifics
--------------------

### 7.1 Format detection

With no `#ARGS` line, the first non-blank data line picks the flag. Check
the `# command:` line in the output pane:

| first data line | flag shown | sample output check |
|-----------------|------------|---------------------|
| `name,quantity,price` (then rows) | `--csv` | the examples file's `$total` column appears |
| `a b` | `--nidx` | `$3 = $1 . $2;` gives `a b ab` |
| `{"a": 1}` | `--jsonl` | `$b = $a + 1;` gives a record with `b=2` |
| `[` on a line by itself, JSON array below | `--json` | same |
| blank line, then CSV | `--csv` (the blank line is skipped) | |

### 7.2 No `#DATA`

Program `$x = 1;` and no data. **Expected** output pane:

```
mlrrepl: no #DATA section — add data below a #DATA marker
```

### 7.3 Bare `#ARGS` keeps detection on

`#ARGS` with nothing after it, CSV data: still `--csv`. `#ARGS --ojson`
alone: detection is off and Miller reads the data as DKVP (so CSV rows
come out as a single field each). This is documented behavior, not a bug.

8. perlrepl specifics
---------------------

| program | `#DATA` | expected command line | expected output |
|---------|---------|-----------------------|-----------------|
| `print "$.: $_";` | `one` / `two` | `perl -n …src… …data…` | `1: one` then `2: two` |
| `print "hi\n";` | none | `perl …src…` (no `-n`, no data file) | `hi` |
| `while (<>) { print uc }` | `a` | `perl …src… …data…` (no `-n`: starts with a keyword) | `A` |
| `my $n = 0; print "$n\n";` | `a` | no `-n` (`my` is a keyword) | `0` |
| `s/foo/bar/; print;` with `#ARGS -p` | `foo` | `perl -n -p …` | `bar` printed once per `-p` plus the explicit print, i.e. twice. Drop the `print` for once. |

9. jqrepl and yqrepl specifics
------------------------------

- `jqrepl`, no `#DATA`, program `{a: 1, b: [1,2]}`: output is the object
  pretty-printed in color (jq colors by default on a tty); command line
  shows `jq -n`.
- `yqrepl`, no `#DATA`, program `{"greeting": "hello"}`: output
  `greeting: hello`; command line shows `yq eval --null-input <expr>`.
- `yqrepl` strips whole-line comments and blank lines from the expression
  it passes to `yq`, but the panes still show them. Put a `# comment` above
  the expression, save, and confirm both panes show it and the output is
  unaffected.
- `yqrepl` with the wrong `yq`: if you can, put the Python `yq` first on
  `PATH` (`pip install yq` in a venv) and launch. **Expected**: no tmux
  session opens. The shell prints:

  ```
  yqrepl: requires Mike Farah's Go yq (https://github.com/mikefarah/yq).
          The 'yq' on your PATH is a different tool: yq 3.x.x
  ```

  and the exit status is 1.

10. Session lifecycle
---------------------

These are the paths that used to delete files out from under a running
REPL or close the wrong window. Run each for at least `awkrepl` and one
other REPL. Watch the temp directory in a second terminal:

```bash
watch -n1 'ls ${TMPDIR:-/tmp} | grep repl-'
```

### 10.1 Detach and reattach

1. Launch `./awkrepl/awkrepl` from a plain shell, load the examples, save.
2. Press `C-b d`.
3. `tmux ls`; `ls /tmp/awkrepl-*`.
4. `tmux attach -t awkrepl-<pid>`.
5. Edit, save.
6. Quit the editor.

**Expected**: step 2 returns you to the shell. Step 3 shows the session
still listed and all eight temp files (`src`, `data`, `args`, `run`,
`fmt`, `helpers`, `cleanup`, `edit`) still present. Step 4 shows the three
panes exactly as you left them. Step 5 reloads the output. Step 6 ends the
session and removes every temp file.

### 10.2 Launch from inside an existing tmux session

1. Start your own tmux session with two windows, each with a shell.
2. From window 1, run `./sedrepl/sedrepl`.
3. `C-b w` to list windows.
4. Switch to window 2 (`C-b 2`) and run `exit` in its shell.
5. Go back to the REPL window. Save the file.
6. `tmux show-hooks -t <your session>`.
7. Quit the editor.

**Expected**: step 2 opens a *new window* named `sedrepl` in your session,
not a new session. Step 3 lists your two windows plus `sedrepl`. Step 4
closes window 2 only: the REPL window and its temp files survive. Step 5
still reloads. Step 6 prints no `pane-exited` hook (the REPLs install
none). Step 7 closes the `sedrepl` window only; your window 1 is intact,
the temp files are gone, your session is still running.

### 10.3 Kill the window from tmux

Launch nested as in 10.2, then from another window run
`tmux kill-window -t sedrepl`. **Expected**: the window is gone within a
second, the temp files are removed (the editor wrapper caught the hangup),
and nothing else in your session changed.

### 10.4 An `entr` pane exits

Launch `./jqrepl/jqrepl` from a plain shell. Move to the bottom-left pane
(`C-b o` or `C-b ↓`), press `C-c`. **Expected**: the whole window closes,
the session ends, and the temp files are removed. Repeat with the
bottom-right pane. Repeat once nested in your own tmux session: only the
REPL's window closes.

### 10.5 Two REPLs at once

Launch `./awkrepl/awkrepl` in one terminal and `./sedrepl/sedrepl` in
another, both from plain shells. Quit one. **Expected**: the other keeps
running and its temp files are untouched; only the quit one's files
disappear.

### 10.6 Ctrl-C in the editor pane

In the editor pane, press `C-c`. **Expected**: the editor handles it as it
normally does (nano shows a hint, vim stays in normal mode). The REPL does
not die (the wrapper ignores INT and QUIT).

11. Environment edge cases
--------------------------

- **`$EDITOR` unset**: `env -u EDITOR ./awkrepl/awkrepl` opens `nano`.
- **`$EDITOR` with flags**: `EDITOR="vim -u NONE" ./awkrepl/awkrepl` opens
  vim with no config. The flags are honored because the wrapper runs the
  editor through the shell.
- **`$TMPDIR` with a space**: `mkdir -p "/tmp/with space" && TMPDIR="/tmp/with space" ./awkrepl/awkrepl`.
  Launches, reloads, quits and cleans up normally. Check `ls "/tmp/with space"` is empty afterwards.
- **Working directory with a space**: `cd` into one and launch. The
  `# work dir:` line shows it correctly and the bottom panes open there
  (`C-b o` into the output pane after it closes, or check with
  `tmux display -p -t <session>:0.1 '#{pane_current_path}'`).
- **`TRACE=1`**: `TRACE=1 ./awkrepl/awkrepl` prints bash `set -x` tracing
  to the launching terminal. Useful when reporting a FAIL.
- **macOS / BSD sed** (UNKNOWN on Linux): every REPL splits the file with
  `sed`. On macOS run the section 2 block for all seven and section 5.5;
  the in-place edits use `sed -i ''` there.
- **Narrow terminal**: resize to 80x24 before launching. All three panes
  must still appear and be usable; nothing is required to fit, but no pane
  may be missing.

12. Makefiles and Docker
------------------------

- `make` at the root and in each subproject prints a colored target list
  (needs `perl`). Expected targets at the root: `help`, `test`, `unit`,
  `e2e`. In a subproject: `help`, `build`, `run`, `test`, `publish`.
- `make publish` in a subproject with no `DOCKER_HUB_USER` stops with
  `set DOCKER_HUB_USER to your Docker Hub account…` and exit status 2, and
  pushes nothing. Verify with `docker images` that nothing was retagged.
- With Docker available (otherwise UNKNOWN), in `awkrepl/`:
  `make build && make run`. Expected: a container opens the three panes
  with the examples file already loaded as `~/.repl.awk`, bat highlighting
  present, nano as the editor. `make run EDITOR=vim` opens vim instead.
  Quitting the editor exits the container. Repeat for one other subproject.

13. workoutrepl specifics
-------------------------

`workoutrepl` saves into a *graded fixture* rather than re-running a text tool,
so the things to look at are on disk as well as in the panes. Use a throwaway
sandbox: `WORKOUT_HOME=/tmp/wo ./workoutrepl/workoutrepl` (default `~/workout`).

1. Launch with no `~/.repl.workout`. Expected: the generated first file is a
   comment block plus `#DAY 1`; the output pane prints
   `# (no #FILE header: nothing written)  saved HH:MM:SS`; within about two
   seconds the right pane grades day 1 (`FAIL: day 01 …`, with `[BAD]` lines
   naming what is missing). Check `ls /tmp/wo/day01` exists.
2. Replace the file with the day-7 piece below and save. Expected: the output
   pane shows `# day 07 · tidy.sh …`, `# wrote:   day07/tidy.sh  (mode 755, …`,
   `# command: ./tidy.sh downloads`, the echo, `# exit:    3`; the right pane
   shows `# workout check 7 …`, then `FAIL: day 07` with `tidy.log is missing`
   among the `[BAD]` lines. `ls -l /tmp/wo/day07/tidy.sh` is executable.

   ```
   #DAY 7
   #FILE tidy.sh
   #RUN ./tidy.sh downloads
   #!/usr/bin/env bash
   echo "placeholder for $1"
   exit 3
   ```
3. Change `#DAY 7` to `#DAY 5` and `#FILE tidy.sh` to `#FILE pe.sh`, save
   twice within two seconds. Expected: the right pane's **last** verdict is
   `FAIL: day 05`; nothing re-grades day 7 afterwards (wait 3 s and look).
4. Add a line `# Run it again` above `#RUN`. Save. Expected: it is a comment:
   the `# command:` line is unchanged (a header is `#KEY` with no space).
5. Set `#FILE ../escape.sh`. Save. Expected:
   `# workoutrepl: #FILE must be a relative path inside the fixture: ../escape.sh`,
   and `ls /tmp/wo/escape.sh` says no such file.
6. Add `#FRESH yes`, create `touch /tmp/wo/day05/marker`, save. Expected: the
   output pane says `# #FRESH: rebuilding the fixture first:` and the marker is
   gone.
7. Remove every header. Save. Expected: the hint
   `# workoutrepl: add a header line  #DAY N  (1..30) and  #FILE name …`, and
   the right pane does not re-grade (its text is unchanged).
8. `./workoutrepl/walk.sh --day 1` in a terminal at least 200x50. Expected: a
   session of its own, the status line `day 1 · piece 1/3 | …`, piece 1 typed
   into vim and saved, both lower panes updated; `F5` types piece 2, `F4` goes
   back; `C-b d` leaves and prints the driver log. Your own `~/.repl.workout`
   and `~/workout` are untouched (the walk uses a throwaway `HOME`).
9. Quit the editor. Expected: the window closes; `ls ${TMPDIR:-/tmp}/workoutrepl-*`
   lists nothing.

14. Known expected failures and skips
-------------------------------------

Rows that are expected to FAIL or be UNKNOWN on a given setup. If your
run shows none of these, confirm the environment really differs before
trusting the all-green result.

| Where | Expected verdict | Why |
|-------|------------------|-----|
| yqrepl, anything, with Go yq 4.2.0 or other pre-4.6 builds | FAIL to launch; `make unit` fails in yqrepl's `01_dependencies.sh`; `make e2e` skips yq | The Mike Farah check greps `yq --version` for `mikefarah`, which old Go builds do not print (4.2.0 prints only `yq version 4.2.0`). `yq eval --null-input` works fine on those builds, so this is a false negative in the detection, not in yq. Observed on this machine on 2026-10-07 with `/usr/local/bin/yq` 4.2.0. |
| yqrepl with Python yq | FAIL to launch, by design | See section 9. |
| Section 12 Docker rows | UNKNOWN without Docker | |
| Section 11 BSD sed row | UNKNOWN on Linux | |
| Section 6.3 without `bat`/`batcat` installed | the "with bat" half is UNKNOWN | |

15. Results log
---------------

Date: ______  Commit: `git rev-parse --short HEAD` ______  Tester: ______

| # | Test | awk | sed | jq | yq | mlr | perl | workout | Notes |
|---|------|-----|-----|----|----|-----|------|---------|-------|
| 2 | launch / layout / quit | | | | | | | | |
| 3 | live reload, nano | | | | | | | | |
| 3 | live reload, vim | | | | | | | | |
| 3 | live reload, other editor: ______ | | | | | | | | |
| 4 | syntax error shown, no crash | | | | | | | | |
| 5.1 | `#ARGS` applied | | | | | | | | |
| 5.2 | lookalike comments ignored | | – | – | – | – | – | – | |
| 5.3 | unmatched-quote warning | | | | | | | | |
| 5.4 | glob not expanded | | – | – | – | – | – | – | |
| 5.5 | `#DATA` on line 1 / `#ARGS` after `#DATA` | | | | | | | | |
| 6.1 | auto-wrap table | | – | – | – | – | – | – | |
| 6.2 | helpers available | | – | – | – | – | – | – | |
| 6.3 | bat present / absent | | | | | | | | |
| 7 | mlr format detection, hint, bare `#ARGS` | – | – | – | – | | – | – | |
| 8 | perl `-n` detection | – | – | – | – | – | | – | |
| 9 | jq/yq null input, yq flavor refusal | – | – | | | – | – | – | |
| 10.1 | detach / reattach | | | | | | | | |
| 10.2 | nested launch, other pane exits | | | | | | | | |
| 10.3 | kill-window cleanup | | | | | | | | |
| 10.4 | entr pane exits | | | | | | | | |
| 10.5 | two REPLs at once | | | | | | | | |
| 10.6 | Ctrl-C in editor pane | | | | | | | | |
| 11 | env edge cases (list which) | | | | | | | | |
| 12 | Makefiles / Docker | | | | | | | | |
| 13 | workoutrepl: launch, day-7 save, day switch, `../` refused, `#FRESH`, hint, walk, quit | – | – | – | – | – | – | | |

Count the FAILs and UNKNOWNs at the bottom. If there are zero of both,
re-read section 14.

FAIL: ____  UNKNOWN: ____
