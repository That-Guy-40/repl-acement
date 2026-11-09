workout/ — the trainer this REPL grades with (vendored)
======================================================

`workoutrepl` is a REPL over a *graded* fixture: a save writes the piece you are
editing into `$WORKOUT_HOME/dayNN/`, runs it, and re-grades the day. The grading
is done by the **30-day Linux command-line workout**, a lab in the
[mklab](https://github.com/That-Guy-40/mklab) repository
(`examples/linux-30-day-command-line-workout/`). The parts of that lab the REPL
needs are copied here so `workoutrepl/` is self-contained:

| Path | What it is |
|------|------------|
| `bin/workout` | the trainer: `list`, `day N`, `setup N`, `check N`, `hint N`, `solution N`, `progress`, plus the plumbing verbs `--day-number` and `--title` the REPL calls |
| `lib/drill-lib.sh` | the helpers every drill is written against (`expect_eq`, `expect_file`, `unknown`, …) and the contract they share |
| `drills/day01.sh` … `day30.sh` | one drill per day: `brief()`, `setup()`, `check()`, `solve()` |
| `demo.sh` | proves every drill is gradable and passable: each checker must FAIL an untouched fixture and PASS its reference solution (60 checks, about 15 s) |

Every drill lives entirely inside `$WORKOUT_HOME` (default `~/workout`); nothing
here writes outside it. The reference solutions are gated: `workout solution N`
shows one only once day N passes (or with `--spoil`).

Not copied: the lab's vendored How-To Geek article (the write-up the workout was
built from), its `RUNBOOK.md`/`WORKOUT.md`, its container specs and its own test
suite. Read those in mklab.

Provenance
----------

| | |
|---|---|
| Source | mklab, `examples/linux-30-day-command-line-workout/` (`bin/`, `lib/`, `drills/`, `demo.sh`) |
| Copied | 2026-11-08 |
| Licence | MIT (mklab's `LICENSE`, reproduced in [`LICENSE`](LICENSE)) |
| Drift | the copies are byte-identical to their source at the copy date, and `workoutrepl`, `walk.sh`, `verify.sh` and `steps/` are the same files in both repositories (each resolves the trainer by looking for `workout/bin/workout` beside itself first). To re-sync, copy the files over and re-run `make test`. |

Running the trainer on its own
------------------------------

```bash
workoutrepl/workout/bin/workout list        # the roster
workoutrepl/workout/bin/workout day 7       # the whole task for day 7
workoutrepl/workout/bin/workout setup 7     # build ~/workout/day07
workoutrepl/workout/bin/workout check 7     # grade it: every assertion, then one PASS/FAIL/UNKNOWN line
workoutrepl/workout/demo.sh                 # all 30 checkers: bite on a fresh fixture, pass on the reference
```

`WORKOUT_HOME` moves the sandbox; `WORKOUT_LIB` points at a different copy of
this directory. The drills assume GNU tools and `LC_ALL=C`; beyond bash and
coreutils they use `awk comm find flock grep gzip join rsync sed sha256sum
shellcheck systemd-analyze tar timeout xargs`, and a checker whose tool is
missing reports `UNKNOWN` by name rather than passing.
