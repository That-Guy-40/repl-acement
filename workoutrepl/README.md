workoutrepl — a REPL over a graded fixture
==========================================

The seventh member of the family is not a text-processing tool. It is the
**30-day Linux command-line workout**, a lab from the
[mklab](https://github.com/That-Guy-40/mklab) repository: thirty drills, each a
fixture on disk under `~/workout/dayNN/` and a checker that grades the *outcome*
you leave there. `workoutrepl` turns that into a loop you never leave: **one file
open in an editor, and every save writes the piece you are working on into the
day's fixture, runs it, and re-grades the whole day** — three tmux panes, driven
by `entr`, exactly like `awkrepl`.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ EDITOR  ~/.repl.workout                                                      │
│   # narration …                                                              │
│   #DAY 7                                                                     │
│   #FILE tidy.sh                                                              │
│   #RUN ./tidy.sh downloads                                                   │
│   #!/usr/bin/env bash                                                        │
│   …the piece…                                                                │
├───────────────────────────────────────┬──────────────────────────────────────┤
│ OUTPUT  entr on ~/.repl.workout       │ CHECK  entr on a stamp the runner    │
│ # day 07 · tidy.sh — …                │        touches                       │
│ # wrote:   day07/tidy.sh  (mode 755…  │ # workout check 7 — graded 22:16:29  │
│ # command: ./tidy.sh downloads        │    [ok]  setup.exe.part … exists     │
│ …the piece's own output…              │    [BAD] downloads/tidy.log is missing│
│ # exit:    1                          │ FAIL: day 07 — tidy.sh … (15 of 18 … │
└───────────────────────────────────────┴──────────────────────────────────────┘
```

The machinery is this repository's: one edited file, one generated runner per
pane, `entr -c` as the only event loop, no tmux hooks, an editor wrapper that
cleans up and closes only its own window. What is new is *what* a save means —
a file written into a graded fixture — and the step files that walk a whole
lesson through the editor pane, piece by piece. The trainer, its helper library
and the thirty drills are vendored under [`workout/`](workout/) (MIT; provenance
in [`workout/README.md`](workout/README.md)), so this directory is
self-contained.

Use it
------

```sh
workoutrepl/workoutrepl               # three panes on ~/.repl.workout (made if missing)
EDITOR=vim workoutrepl/workoutrepl    # your editor; nano is the fallback
```

Edit, `:w`, look down. The headers at the top of the file say where the body goes:

```
# anything above the first header is narration — it is never written anywhere
#DAY 7                  the day (1..30, day07, boss1); its fixture is built if missing
#FILE tidy.sh           the file under $WORKOUT_HOME/day07 the BODY is written to
#RUN ./tidy.sh downloads   run in the fixture after the write (default: bash ./FILE for *.sh)
#MODE 755               optional (default 755 when the body starts with #!, else 644)
#TIMEOUT 20             optional; seconds before the run is killed
#FRESH yes              optional; rebuild the fixture before every write (a piece that
                        consumes its inputs — a rename, a move); it resets the WHOLE day
<body>
#DATA                   optional; the lines below it are the run's stdin
```

A header is `#KEY` with **no space after the `#`** — `# Run it twice` in a
comment is a comment. (The other six REPLs allow `# data` with a space; here a
lesson's narration is full of lines like `# Day 7` and `# Run it`, so the rule
is stricter.) The write is atomic (`mktemp` in the fixture directory, `chmod`,
`mv -f`); `#FILE` must be relative and may not climb out (`../`). `workout setup
N` resets a day by hand; nothing the REPL does is ever irreversible beyond that
fixture. `WORKOUT_HOME` moves the sandbox (default `~/workout`); `workout day N`
prints a day's whole task.

**The lesson, piece by piece.** `steps/dayNN/MM_<piece>.repl` holds every day's
lesson split into its graded pieces — a `tidy.sh`, a `make-project.sh`, an
`answers.txt` — each as narration, headers and a **skeleton** that does
something visible but not yet right. The walker types them into the editor pane
for you:

```sh
workoutrepl/walk.sh --day 7              # a tmux session of its own; F5 next piece, F4 previous;
                                         # between pieces the editor is yours — edit, save, read
workoutrepl/walk.sh --days 1-3           # several days in one sitting
workoutrepl/walk.sh --day 7 --solutions  # type the REFERENCE content instead of the skeleton
workoutrepl/walk.sh --day 7 --timer      # self-running, on each step's #> pause:
make walk DAY=7                          # the same, from this directory
```

The walk uses a throwaway `HOME` (so `~/.repl.workout` and `~/workout` are the
walk's, not yours) and `vim -u workoutrepl/vimrc`. Your own REPL session is
`workoutrepl/workoutrepl` in your own home; copy a step file's text into it
whenever you want the narration beside your work.

What is proven, and how
-----------------------

`verify.sh` is the headless instrument. It runs `walk.sh --fast --no-attach
--capture` over a day and grades the **panes** against each step's assertion
rows:

```
#> out: TEXT          the OUTPUT pane must show TEXT      #> out-not: TEXT     must not
#> check: TEXT        the CHECK pane must show TEXT       #> check-not: TEXT   must not
#> wait: TEXT         (walker) wait for TEXT in OUTPUT; default: the `# wrote: … saved` line
#> pause: SECS        (walker, --timer) narration time
```

Two modes, both required (`make verify DAYS=1-3` runs both):

| mode | what is typed | what must hold |
|---|---|---|
| skeleton (default) | the pieces as the learner first sees them | every `#> out/out-not/check/check-not` row; the `# wrote:` line for the step's `#FILE`; **no step ends the day on PASS** |
| `--solutions` | `steps/dayNN/solutions/<step>` if present, else the `#FILE` the day's reference `solve()` leaves in a fresh fixture | every piece written and run (`# exit:`), and the **last** piece leaves the CHECK pane on `PASS: day NN` |

Before it looks at a real day, `verify.sh` plants a failing row, a forbidden
text and a missing PASS into a fake capture and requires its own grader to
report all three — a grader that has never been seen failing is not known to be
attached to anything. It paid for itself on the first afternoon: the walker had
been reading the panes' **visible** text, and a long run pushed the `# wrote:`
line off the top while a re-grade with the same verdict left the visible area
unchanged — both read as timeouts on correct pieces. The waits now count
matching lines in the whole scrollback, and each capture is scoped to the last
run's header. A second finding was in the REPL itself: the first save after
launch re-stamps once to beat `entr`'s arming race, and that re-stamp carried
the *launch* day, so a save that switched days inside two seconds was followed
by a grade of the old day. A third was in a **drill**: day 7's checker demanded
exactly two `SKIPPED` lines while its brief said a re-run may log them again;
the REPL's second save is a re-run, and a correct `tidy.sh` failed.

Measured 2026-11-08 (tmux 3.6, entr 5.7, vim), from the mklab copy of the same
files:

```
$ verify.sh --days all
PASS: repl steps (skeleton) — 97 pieces of day(s) 1 … 30 typed into the editor pane, each written+run in the OUTPUT pane and re-graded in the CHECK pane; … assertions hold
$ verify.sh --days all --solutions
PASS: repl steps (solutions) — 97 pieces … every day ends on PASS
```

Tests
-----

`make test` runs the smoke and integration suites in [`tests/`](tests/), in the
shape of the other six:

| Suite | What it proves |
|---|---|
| `smoke/01_dependencies.sh` | tmux, entr, sed, awk, `timeout`; the vendored trainer answers `--day-number` and `--title`, refuses day 31; 30 drills present |
| `smoke/02_divide.sh` | `_wr_divide`/`_wr_header`: the six headers (any case, colon form, last one wins), body after the LAST header, narration dropped, `# Run it twice` is a comment, the `#DATA` split |
| `smoke/03_steps_complete.sh` | every day 1..30 has step files; each parses with the REPL's *own* divider, names its day and a relative `#FILE`, has positive and negative rows and a reference body — four planted defects are its negative control |
| `smoke/04_makefile.sh` | `make help` lists `walk`, `verify`, `demo`; `make publish` refuses without `DOCKER_HUB_USER` and pushes only to it (fake docker) |
| `integration/01_runner.sh` | `_wr_run` against a scratch `WORKOUT_HOME`: fixture built on demand, `# wrote:`/`# command:`/`# exit:`, mode 755 for a `#!` body, `#MODE`, `#DATA` as stdin, `#TIMEOUT` → `exit: 124`, `#FRESH` rebuilds, no `#DAY` → hint and no stamp, `#DAY 99` refused, `../` and absolute `#FILE` refused with nothing written; `_wr_check` grades the stamped day and names the defect |
| `integration/02_editor_pane.sh` | the editor wrapper runs `$EDITOR` through the shell, removes all eight scratch files on exit; setup refuses a missing trainer by name |
| `integration/03_trainer_demo.sh` | `workout/demo.sh`: every one of the 30 checkers FAILS an untouched fixture and PASSES its reference solution (60 checks) |
| `integration/04_verify_walk.sh` | `verify.sh` in both modes over days 1–3 (`WORKOUTREPL_DAYS=all` for every day), and it must have run its own negative control |

The live UI is covered from the repo root: [`tests/e2e/18_workoutrepl_live.sh`](../tests/e2e/18_workoutrepl_live.sh)
drives a real session through `ttydrive` (panes up; a save builds the fixture,
writes the piece, shows `exit:    3`, re-grades day 7 with its `[BAD]` line;
switching `#DAY` grades the new day last; no `#DAY` prints the hint; quitting
leaves no scratch files), and the detach/reattach and nested-tmux suites
(`16_*`, `17_*`) include `workoutrepl` alongside the other six.

Two of the new assertions were watched to bite before they were trusted:
deleting the `#FILE` escape check makes `01_runner.sh` fail its three refusal
rows, and `03_steps_complete.sh` reports all four planted defects on every run.

Docker
------

`make build && make run` opens the REPL in a container with every tool the
drills grade with (`gawk`, `rsync`, `shellcheck`, `systemd-analyze`, `flock`,
…). The image runs as the user `learner`, never root: day 27 makes a source file
unreadable and expects `rsync` to fail on it, which root never does — as root,
`demo.sh` inside the image reports exactly that one failure.

Writing a piece
---------------

One piece per graded file; a command-type task (day 2's globbing, day 8's six
grep outputs) becomes a small descriptive script — `make-project.sh`,
`errors-count.sh` — run by the default `bash ./FILE` and followed in `#RUN` by a
`cat` of what it should have produced, so the OUTPUT pane shows the result *and*
the missing-file error while the skeleton is wrong. The skeleton should **do
something visible and be wrong in the way the lesson is about** (print the lines
when a file is wanted, forget the one flag, fork where an expansion belongs);
the narration says what to change and why, never the answer. The `#> check:`
rows quote the checker's own `[BAD]` text, so a step is also a test that the
drill names its defect. Days whose checker returns early while a later piece is
missing (15, 25, 30) assert the OUTPUT pane instead.

The pieces — every step file, by day
------------------------------------

One row per day; each piece is the file the walker types (its first line is the
title shown here), and a command-type piece also names the reference body under
`solutions/` that `--solutions` mode types in place of the skeleton.

| day | pieces |
|---|---|
| day01 | [`01_inputrc.repl`](steps/day01/01_inputrc.repl) — inputrc: make the arrow keys search history by prefix<br>[`02_history.sh.repl`](steps/day01/02_history.sh.repl) — history.sh: a history worth searching<br>[`03_answers.txt.repl`](steps/day01/03_answers.txt.repl) — answers.txt: three keys you will use every day from now on |
| day02 | [`01_make-project.sh.repl`](steps/day02/01_make-project.sh.repl) — make-project.sh: a nine-directory tree from ONE mkdir (reference: [`solutions/01_make-project.sh`](steps/day02/solutions/01_make-project.sh))<br>[`02_clean-tmp.sh.repl`](steps/day02/02_clean-tmp.sh.repl) — clean-tmp.sh: delete every .tmp EXCEPT keep.tmp, in one rm (reference: [`solutions/02_clean-tmp.sh`](steps/day02/solutions/02_clean-tmp.sh))<br>[`03_logs.sh.repl`](steps/day02/03_logs.sh.repl) — logs.sh: every .log at ANY depth, with ** instead of find (reference: [`solutions/03_logs.sh`](steps/day02/solutions/03_logs.sh))<br>[`04_images.sh.repl`](steps/day02/04_images.sh.repl) — images.sh: .jpg .JPG .Jpg are one extension to the eye (reference: [`solutions/04_images.sh`](steps/day02/solutions/04_images.sh)) |
| day03 | [`01_lower.sh.repl`](steps/day03/01_lower.sh.repl) — lower.sh: rename eleven hostile names without losing one |
| day04 | [`01_split.sh.repl`](steps/day04/01_split.sh.repl) — split.sh: stdout here, stderr there, and BOTH in a third file<br>[`02_swap.sh.repl`](steps/day04/02_swap.sh.repl) — swap.sh: trade stdout and stderr with a third descriptor<br>[`03_fd3.sh.repl`](steps/day04/03_fd3.sh.repl) — fd3.sh: open a file yourself, on a descriptor you choose |
| day05 | [`01_pe.sh.repl`](steps/day05/01_pe.sh.repl) — pe.sh: dirname, basename and friends with no fork at all<br>[`02_defaults.sh.repl`](steps/day05/02_defaults.sh.repl) — defaults.sh: six lines driven entirely by the environment |
| day06 | [`01_pipeline.sh.repl`](steps/day06/01_pipeline.sh.repl) — pipeline.sh: a script that knows when it failed<br>[`02_status.sh.repl`](steps/day06/02_status.sh.repl) — status.sh: the status of EVERY stage, not just the last<br>[`03_cleanup.sh.repl`](steps/day06/03_cleanup.sh.repl) — cleanup.sh: a trap that runs on the way out, every way out |
| day07 | [`01_tidy.sh.repl`](steps/day07/01_tidy.sh.repl) — tidy.sh: sort a hostile download directory, safely, twice |
| day08 | [`01_errors-count.sh.repl`](steps/day08/01_errors-count.sh.repl) — errors-count.txt: a count per file, with grep alone (reference: [`solutions/01_errors-count.sh`](steps/day08/solutions/01_errors-count.sh))<br>[`02_with-timeout.sh.repl`](steps/day08/02_with-timeout.sh.repl) — with-timeout.txt: just the FILENAMES that match (reference: [`solutions/02_with-timeout.sh`](steps/day08/solutions/02_with-timeout.sh))<br>[`03_without-timeout.sh.repl`](steps/day08/03_without-timeout.sh.repl) — without-timeout.txt: the files that do NOT match (reference: [`solutions/03_without-timeout.sh`](steps/day08/solutions/03_without-timeout.sh))<br>[`04_ips.sh.repl`](steps/day08/04_ips.sh.repl) — ips.txt: the MATCH only, not the line (reference: [`solutions/04_ips.sh`](steps/day08/solutions/04_ips.sh))<br>[`05_context.sh.repl`](steps/day08/05_context.sh.repl) — context.txt: a window around the match (reference: [`solutions/05_context.sh`](steps/day08/solutions/05_context.sh))<br>[`06_disk.sh.repl`](steps/day08/06_disk.sh.repl) — disk.txt: path, line number, line (reference: [`solutions/06_disk.sh`](steps/day08/solutions/06_disk.sh)) |
| day09 | [`01_conf-edit.sh.repl`](steps/day09/01_conf-edit.sh.repl) — conf-edit.sh: four edits in place, with a backup (reference: [`solutions/01_conf-edit.sh`](steps/day09/solutions/01_conf-edit.sh))<br>[`02_hosts-swapped.sh.repl`](steps/day09/02_hosts-swapped.sh.repl) — hosts-swapped.txt: swap two columns with a backreference (reference: [`solutions/02_hosts-swapped.sh`](steps/day09/solutions/02_hosts-swapped.sh))<br>[`03_names.sh.repl`](steps/day09/03_names.sh.repl) — names.txt: a line range (reference: [`solutions/03_names.sh`](steps/day09/solutions/03_names.sh))<br>[`04_versions.sh.repl`](steps/day09/04_versions.sh.repl) — versions.txt: extract a token with s///p (reference: [`solutions/04_versions.sh`](steps/day09/solutions/04_versions.sh)) |
| day10 | [`01_by-region.sh.repl`](steps/day10/01_by-region.sh.repl) — by-region.txt: sum per key, report at END (reference: [`solutions/01_by-region.sh`](steps/day10/solutions/01_by-region.sh))<br>[`02_top-product.sh.repl`](steps/day10/02_top-product.sh.repl) — top-product.txt: the max of an aggregate (reference: [`solutions/02_top-product.sh`](steps/day10/solutions/02_top-product.sh))<br>[`03_status-hist.sh.repl`](steps/day10/03_status-hist.sh.repl) — status-hist.txt: count from the END of the line (reference: [`solutions/03_status-hist.sh`](steps/day10/solutions/03_status-hist.sh))<br>[`04_wide.sh.repl`](steps/day10/04_wide.sh.repl) — wide.txt: fixed-width columns with printf (reference: [`solutions/04_wide.sh`](steps/day10/solutions/04_wide.sh)) |
| day11 | [`01_joined.sh.repl`](steps/day11/01_joined.sh.repl) — joined.tsv: join two files on a key (reference: [`solutions/01_joined.sh`](steps/day11/solutions/01_joined.sh))<br>[`02_top3.sh.repl`](steps/day11/02_top3.sh.repl) — top3.txt: sort by a numeric field, descending (reference: [`solutions/02_top3.sh`](steps/day11/solutions/02_top3.sh))<br>[`03_removed.sh.repl`](steps/day11/03_removed.sh.repl) — removed.txt: set difference with comm (reference: [`solutions/03_removed.sh`](steps/day11/solutions/03_removed.sh))<br>[`04_added.sh.repl`](steps/day11/04_added.sh.repl) — added.txt: the other difference (reference: [`solutions/04_added.sh`](steps/day11/solutions/04_added.sh))<br>[`05_initials.sh.repl`](steps/day11/05_initials.sh.repl) — initials.txt: cut, tr, and uniq WITHOUT sort (reference: [`solutions/05_initials.sh`](steps/day11/solutions/05_initials.sh))<br>[`06_paired.sh.repl`](steps/day11/06_paired.sh.repl) — paired.txt: columns side by side with paste (reference: [`solutions/06_paired.sh`](steps/day11/solutions/06_paired.sh)) |
| day12 | [`01_big.sh.repl`](steps/day12/01_big.sh.repl) — big.txt: a size predicate (reference: [`solutions/01_big.sh`](steps/day12/solutions/01_big.sh))<br>[`02_old.sh.repl`](steps/day12/02_old.sh.repl) — old.txt: a file as a timestamp (reference: [`solutions/02_old.sh`](steps/day12/solutions/02_old.sh))<br>[`03_empty.sh.repl`](steps/day12/03_empty.sh.repl) — empty.txt: -empty (reference: [`solutions/03_empty.sh`](steps/day12/solutions/03_empty.sh))<br>[`04_count.sh.repl`](steps/day12/04_count.sh.repl) — count.txt: count files, not lines (reference: [`solutions/04_count.sh`](steps/day12/solutions/04_count.sh))<br>[`05_renamed.sh.repl`](steps/day12/05_renamed.sh.repl) — renamed/: hand find's results to cp, safely (reference: [`solutions/05_renamed.sh`](steps/day12/solutions/05_renamed.sh))<br>[`06_keys.sh.repl`](steps/day12/06_keys.sh.repl) — one chmod for all the keys: -exec … {} + (reference: [`solutions/06_keys.sh`](steps/day12/solutions/06_keys.sh)) |
| day13 | [`01_emails.sh.repl`](steps/day13/01_emails.sh.repl) — emails.txt: LINES containing a plausible address (reference: [`solutions/01_emails.sh`](steps/day13/solutions/01_emails.sh))<br>[`02_iso-dates.sh.repl`](steps/day13/02_iso-dates.sh.repl) — iso-dates.txt: TOKENS, not lines (reference: [`solutions/02_iso-dates.sh`](steps/day13/solutions/02_iso-dates.sh))<br>[`03_hex.sh.repl`](steps/day13/03_hex.sh.repl) — hex.txt: exactly six, as a whole word (reference: [`solutions/03_hex.sh`](steps/day13/solutions/03_hex.sh))<br>[`04_ipv4.sh.repl`](steps/day13/04_ipv4.sh.repl) — ipv4.txt: VALID addresses, octet by octet (reference: [`solutions/04_ipv4.sh`](steps/day13/solutions/04_ipv4.sh))<br>[`05_doubled.sh.repl`](steps/day13/05_doubled.sh.repl) — doubled.txt: a backreference (reference: [`solutions/05_doubled.sh`](steps/day13/solutions/05_doubled.sh))<br>[`06_pattern-bre.txt.repl`](steps/day13/06_pattern-bre.txt.repl) — pattern-bre.txt: the same regex in the OTHER dialect |
| day14 | [`01_top-ips.sh.repl`](steps/day14/01_top-ips.sh.repl) — top-ips.txt: count, sort, head (reference: [`solutions/01_top-ips.sh`](steps/day14/solutions/01_top-ips.sh))<br>[`02_404-by-hour.sh.repl`](steps/day14/02_404-by-hour.sh.repl) — 404-by-hour.txt: filter, extract, count (reference: [`solutions/02_404-by-hour.sh`](steps/day14/solutions/02_404-by-hour.sh))<br>[`03_bytes-by-country.sh.repl`](steps/day14/03_bytes-by-country.sh.repl) — bytes-by-country.tsv: join, then aggregate (reference: [`solutions/03_bytes-by-country.sh`](steps/day14/solutions/03_bytes-by-country.sh))<br>[`04_unknown-ips.sh.repl`](steps/day14/04_unknown-ips.sh.repl) — unknown-ips.txt: the ips join dropped (reference: [`solutions/04_unknown-ips.sh`](steps/day14/solutions/04_unknown-ips.sh))<br>[`05_suspects.sh.repl`](steps/day14/05_suspects.sh.repl) — suspects.txt: a threshold on an aggregate (reference: [`solutions/05_suspects.sh`](steps/day14/solutions/05_suspects.sh))<br>[`06_report.sh.repl`](steps/day14/06_report.sh.repl) — report.md: four numbers, one printf (reference: [`solutions/06_report.sh`](steps/day14/solutions/06_report.sh)) |
| day15 | [`01_lib.sh.repl`](steps/day15/01_lib.sh.repl) — lib.sh: five functions, meant to be sourced |
| day16 | [`01_tool.sh.repl`](steps/day16/01_tool.sh.repl) — tool.sh: getopts and good manners |
| day17 | [`01_gen-config.sh.repl`](steps/day17/01_gen-config.sh.repl) — gen-config.sh: a here-document that is half template, half program<br>[`02_atomic-update.sh.repl`](steps/day17/02_atomic-update.sh.repl) — atomic-update.sh: never let a reader see half a file<br>[`03_csv-count.sh.repl`](steps/day17/03_csv-count.sh.repl) — csv-count.sh: split a string into an array, no forks |
| day18 | [`01_supervise.sh.repl`](steps/day18/01_supervise.sh.repl) — supervise.sh: start them all, then wait for each by PID<br>[`02_graceful.sh.repl`](steps/day18/02_graceful.sh.repl) — graceful.sh: a TERM handler that leaves things tidy<br>[`03_answers.txt.repl`](steps/day18/03_answers.txt.repl) — answers.txt: two numbers worth knowing by heart |
| day19 | [`01_introspect.sh.repl`](steps/day19/01_introspect.sh.repl) — introspect.sh: ask the kernel about THIS process<br>[`02_answers.txt.repl`](steps/day19/02_answers.txt.repl) — answers.txt: two /proc facts |
| day20 | [`01_make-team.sh.repl`](steps/day20/01_make-team.sh.repl) — make-team.sh: a shared directory, in symbolic modes<br>[`02_umask.sh.repl`](steps/day20/02_umask.sh.repl) — umask.sh: the subtraction everyone forgets<br>[`03_links.sh.repl`](steps/day20/03_links.sh.repl) — links.sh: two names for one inode, and a pointer to a name (reference: [`solutions/03_links.sh`](steps/day20/solutions/03_links.sh))<br>[`04_answers.txt.repl`](steps/day20/04_answers.txt.repl) — answers.txt: one sentence about a common mistake |
| day21 | [`01_runjobs.sh.repl`](steps/day21/01_runjobs.sh.repl) — runjobs.sh: xargs -P in forty lines |
| day22 | [`01_make-archive.sh.repl`](steps/day22/01_make-archive.sh.repl) — make-archive.sh: an archive that leaves the junk out (reference: [`solutions/01_make-archive.sh`](steps/day22/solutions/01_make-archive.sh))<br>[`02_listing.sh.repl`](steps/day22/02_listing.sh.repl) — listing.txt: tar -t, sorted (reference: [`solutions/02_listing.sh`](steps/day22/solutions/02_listing.sh))<br>[`03_restore.sh.repl`](steps/day22/03_restore.sh.repl) — restore/: extract somewhere else, with modes intact (reference: [`solutions/03_restore.sh`](steps/day22/solutions/03_restore.sh))<br>[`04_one-file.sh.repl`](steps/day22/04_one-file.sh.repl) — one-file/: extract a single member (reference: [`solutions/04_one-file.sh`](steps/day22/solutions/04_one-file.sh))<br>[`05_flat.sh.repl`](steps/day22/05_flat.sh.repl) — flat/: drop the packager's top directory (reference: [`solutions/05_flat.sh`](steps/day22/solutions/05_flat.sh)) |
| day23 | [`01_mirror-a.sh.repl`](steps/day23/01_mirror-a.sh.repl) — mirror-a/: the CONTENTS of src/ (reference: [`solutions/01_mirror-a.sh`](steps/day23/solutions/01_mirror-a.sh))<br>[`02_mirror-b.sh.repl`](steps/day23/02_mirror-b.sh.repl) — mirror-b/: src/ itself, placed inside (reference: [`solutions/02_mirror-b.sh`](steps/day23/solutions/02_mirror-b.sh))<br>[`03_mirror-x.sh.repl`](steps/day23/03_mirror-x.sh.repl) — mirror-x/: contents, minus the junk (reference: [`solutions/03_mirror-x.sh`](steps/day23/solutions/03_mirror-x.sh))<br>[`04_synced.sh.repl`](steps/day23/04_synced.sh.repl) — synced/: a mirror that is allowed to forget (reference: [`solutions/04_synced.sh`](steps/day23/solutions/04_synced.sh)) |
| day24 | [`01_snapshot.sh.repl`](steps/day24/01_snapshot.sh.repl) — snapshot.sh: a full tree every time, paid for once<br>[`02_take-snapshots.sh.repl`](steps/day24/02_take-snapshots.sh.repl) — take-snapshots.sh: three states, three snapshots (reference: [`solutions/02_take-snapshots.sh`](steps/day24/solutions/02_take-snapshots.sh)) |
| day25 | [`01_manifest.sh.repl`](steps/day25/01_manifest.sh.repl) — manifest.sh: digests with portable paths<br>[`02_verify.sh.repl`](steps/day25/02_verify.sh.repl) — verify.sh: the three ways a backup can lie |
| day26 | [`01_backup.timer.repl`](steps/day26/01_backup.timer.repl) — backup.timer: say WHEN, then ask systemd what you said<br>[`02_backup.service.repl`](steps/day26/02_backup.service.repl) — backup.service: the unit the timer fires<br>[`03_cron.txt.repl`](steps/day26/03_cron.txt.repl) — cron.txt: five fields and a command<br>[`04_with-lock.sh.repl`](steps/day26/04_with-lock.sh.repl) — with-lock.sh: two of you must never run at once |
| day27 | [`01_backup.sh.repl`](steps/day27/01_backup.sh.repl) — backup.sh: the script that runs when nobody is watching |
| day28 | [`01_vault.sh.repl`](steps/day28/01_vault.sh.repl) — vault.sh: the week, assembled<br>[`02_vault.timer.repl`](steps/day28/02_vault.timer.repl) — vault.timer: daily at midnight<br>[`03_vault.service.repl`](steps/day28/03_vault.service.repl) — vault.service: oneshot, absolute |
| day29 | [`01_legacy.sh.repl`](steps/day29/01_legacy.sh.repl) — legacy.sh: the cheapest code review you will ever get |
| day30 | [`01_10-path.sh.repl`](steps/day30/01_10-path.sh.repl) — bashrc.d/10-path.sh: safe to source twice<br>[`02_20-functions.sh.repl`](steps/day30/02_20-functions.sh.repl) — bashrc.d/20-functions.sh: three functions, not aliases<br>[`03_30-history.sh.repl`](steps/day30/03_30-history.sh.repl) — bashrc.d/30-history.sh: day 1, carried forward<br>[`04_README.md.repl`](steps/day30/04_README.md.repl) — bashrc.d/README.md: the one line that loads the rest<br>[`05_graduation.txt.repl`](steps/day30/05_graduation.txt.repl) — graduation.txt: what you are taking home |

Attribution
-----------

The pane layout, generated-runner and cleanup-wrapper structure follow Kevin
Ernst's awkrepl (<https://github.com/ernstki/awkrepl>, MIT), as everything in
this repository does; `walk.sh` and `verify.sh` follow the shape of
[`demo/play.sh`](../demo/play.sh) and [`demo/verify.sh`](../demo/verify.sh).
The workout itself — trainer, drills and lesson pieces — is from mklab's
`examples/linux-30-day-command-line-workout/` (MIT, see
[`workout/README.md`](workout/README.md)), which also keeps the How-To Geek
article the workout was built from; `workoutrepl`, `walk.sh`, `verify.sh` and
`steps/` are the same files in both repositories.
