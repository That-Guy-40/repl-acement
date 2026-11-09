tests/ — end-to-end (live UI) tests
===================================

Each subproject (`awkrepl/`, `sedrepl/`, …) has its own `tests/smoke` and
`tests/integration` suites. Those source the REPL script and call its shell
functions directly — they never launch the terminal UI, so they don't cover
the part a user actually sees: the three-pane tmux session and the `entr`
event loop that re-runs the tool when you save.

This directory closes that gap. It drives each REPL's **real** tmux session
and checks that saving the file live-reloads the output.

Layout
------

| Path | What it is |
|------|------------|
| `lib/ttydrive` | the terminal driver, vendored from [socwrap][] (`tools/ttydrive`) |
| `lib/replpty.sh` | helpers that launch a REPL under ttydrive, edit its file, read the panes |
| `lib/helpers.sh` | the shared `assert_*` / `pass` / `fail` counters |
| `e2e/1[0-5]_*.sh` | one live-UI suite per tool REPL |
| `e2e/16_detach_reattach.sh` | detach, reattach and quit each REPL (all seven); checks the session and its temp files survive a detach, and that quitting the editor (whose pane wrapper then cleans up) removes them and ends the session |
| `e2e/17_nested_tmux.sh` | launches each REPL (all seven) from a pane inside a host tmux session (its own server, not ttydrive), so it opens as a new window; checks it survives other panes exiting, leaves no `pane-exited` hooks on the session, still reloads on save, and on quitting closes only its own window and removes its temp files; the same cleanup is checked when the REPL window is killed from tmux and when one of its `entr` panes exits |
| `e2e/18_workoutrepl_live.sh` | the seventh REPL, `workoutrepl`, whose save writes into a graded fixture: panes up, a save builds the fixture and writes/runs the piece (`exit:    3`), the check pane re-grades the day and names the defect, switching `#DAY` grades the new day last, no `#DAY` prints the hint, quitting leaves no scratch files |
| `e2e/run.sh` | runs them all |

How it works
------------

`ttydrive` runs a program in a real terminal (a private tmux server) that
outlives each call, so a test can type, wait for text, read the screen and
collect the exit status the way a person would. The helper launches a REPL
in a 120x40 terminal with `TMUX` cleared, so the REPL starts its own tmux
session that attaches to ttydrive's visible pane — what ttydrive captures is
the composited three-pane screen a user sees. The REPL's own tmux server is
isolated under a per-run `TMUX_TMPDIR` so cleanup kills it precisely, and
`HOME` (where the edited file lives) and `TMPDIR` (the REPL's scratch files)
also point into the per-run work area. The editor pane is replaced with a
keep-alive no-op, and the edited file is rewritten from the test to drive the
`entr` reload the same way a save would. Before each rewrite the helper waits
for the screen to settle, so `entr` has armed its watch and back-to-back edits
don't coalesce into one reload.

Because the three panes are captured as one composited screen, the two bottom
panes share each text row. Assert with **distinctive substrings**, not
`^line$` anchors.

Running
-------

```bash
make e2e            # from the repo root
# or
bash tests/e2e/run.sh
```

Requirements: bash 4+, `tmux` (3.0+) and `entr`, plus the tool a given suite
drives (`gawk`, `sed`, `jq`, `yq`, `mlr`, `perl`; `workoutrepl` needs only bash and coreutils for its suite). A suite that finds `tmux`,
`entr` or its tool missing prints `SKIP` and passes. The `yq` suite additionally skips unless the `yq`
on `PATH` is [Mike Farah's Go yq][mf] (yqrepl targets that one, not the
unrelated Python `yq`).

[socwrap]: https://github.com/That-Guy-40/socwrap
[mf]: https://github.com/mikefarah/yq
