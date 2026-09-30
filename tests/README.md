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
| `e2e/*.sh` | one live-UI suite per REPL |
| `e2e/run.sh` | runs them all |

How it works
------------

`ttydrive` runs a program in a real terminal (a private tmux server) that
outlives each call, so a test can type, wait for text, read the screen and
collect the exit status the way a person would. The helper launches a REPL
with `TMUX` cleared, so the REPL starts its own tmux session that attaches to
ttydrive's visible pane — what ttydrive captures is the composited three-pane
screen a user sees. The REPL's own tmux server is isolated under a per-run
`TMUX_TMPDIR` so cleanup kills it precisely. The editor pane is replaced with
a keep-alive no-op, and the edited file is rewritten from the test to drive
the `entr` reload the same way a save would.

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

Requirements: `tmux` (3.0+) and `entr`, plus the tool a given suite drives
(`gawk`, `sed`, `jq`, `yq`, `mlr`, `perl`). A suite whose tool is missing
prints `SKIP` and passes. The `yq` suite additionally skips unless the `yq`
on `PATH` is [Mike Farah's Go yq][mf] (yqrepl targets that one, not the
unrelated Python `yq`).

[socwrap]: https://github.com/That-Guy-40/socwrap
[mf]: https://github.com/mikefarah/yq
