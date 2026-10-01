repl-acement
============

A collection of interactive REPLs for classic Unix text-processing tools.
Each one opens a three-pane tmux session: editor on top, output bottom-left,
source bottom-right (pretty-printed by `gawk` for awkrepl, syntax-highlighted
with `bat` for the others when it is installed). Save the file and the output
pane re-runs at once; the source pane refreshes about a second later. Above the
results, the output pane shows the command line that was run and, for every
REPL except awkrepl, the source as well.

| Tool | REPL | What it does |
|------|------|--------------|
| [AWK](awkrepl/) | `awkrepl` | Pattern scanning and processing |
| [sed](sedrepl/) | `sedrepl` | Stream editing and substitution |
| [jq](jqrepl/)  | `jqrepl`  | JSON filtering and transformation |
| [yq](yqrepl/)  | `yqrepl`  | YAML/JSON/TOML filtering (Mike Farah's yq) |
| [mlr](mlrrepl/) | `mlrrepl` | Tabular/CSV data processing with Miller |
| [Perl](perlrepl/) | `perlrepl` | The punchline awkrepl's README set up |

All six share the same file conventions:

- Lines after `#DATA` are supplied as input to the tool
- Lines starting with `#ARGS` are passed as command-line flags
- Without `#DATA`: `awkrepl` and `sedrepl` run against an empty data file,
  `jqrepl` runs `jq -n` and `yqrepl` runs `yq eval --null-input` (null input),
  `perlrepl` runs the script once with no input file, and `mlrrepl` prints a
  hint instead of running

**Comment handling**: `awkrepl` strips whole-line `#` comments and blank lines
from the source before passing it to `gawk`. `yqrepl` likewise drops
whole-line comments and blank lines from the expression it passes to `yq`
(the panes still show them). `sedrepl`, `jqrepl`, `mlrrepl` and `perlrepl`
pass comments through unchanged — their tools support `#` natively.

**Auto-wrap**: `awkrepl` wraps a bare program (one that doesn't already start
with `{`, `BEGIN`/`END`, or a simple pattern) in `{ }` when there is `#DATA`,
or in `END { }` when there isn't; `perlrepl` detects bare per-line expressions
and adds `-n` automatically when there is `#DATA`.

**`#ARGS` quoting**: `#ARGS` is parsed with shell-style quoting, so a value
that contains spaces must be quoted — `#ARGS -v "greeting=hello world"` is one
argument, while `#ARGS -v greeting=hello world` is three. Quotes and
backslash escapes are the only things interpreted: a `*` or other glob
character is passed through literally and is never expanded against the
working directory.

**`yq` flavor**: `yqrepl` requires [Mike Farah's Go `yq`][yq-mf]. The unrelated
Python `yq` (a jq wrapper) uses a different grammar; `yqrepl` detects it and
refuses to launch with a clear message rather than failing cryptically.

**Temp files**: each REPL keeps its scratch files under `$TMPDIR` (default
`/tmp`) and removes them when its tmux session ends. Detaching (`C-b d`) does
not end the session: it keeps running with its files, and you can reattach
with `tmux attach -t <tool>repl-<pid>`. When started from inside an existing
tmux session (a new window rather than a new session), removal relies on a
tmux `pane-exited` hook and is best-effort.

[yq-mf]: https://github.com/mikefarah/yq


Requirements
------------

- bash
- tmux
- [entr](http://eradman.com/entrproject/)
- the relevant tool (`gawk`, `sed`, `jq`, [Mike Farah's `yq`][yq-mf], `mlr`, `perl`)
- `sed` (every REPL uses it to split the file at `#DATA`/`#ARGS`)
- `perl` for `awkrepl` too (it decides whether to auto-wrap the program)
- `xargs` (from findutils; used to parse `#ARGS` — almost always already present)
- [bat](https://github.com/sharkdp/bat) (optional, syntax highlighting; also
  found under its Debian/Ubuntu name `batcat`)


Running tests
-------------

Each subproject has its own smoke + integration suite:

```bash
cd awkrepl  && make test
cd sedrepl  && make test
cd jqrepl   && make test
cd yqrepl   && make test
cd mlrrepl  && make test
cd perlrepl && make test
```

Each suite's dependency check fails if its tool, `tmux` or `entr` is missing
(e.g. `apt install miller` for mlrrepl); yqrepl's also fails unless the `yq`
on `PATH` is Mike Farah's.

From the repo root, `make` drives all of them plus the end-to-end suite:

```bash
make unit   # every subproject's smoke + integration suites
make e2e    # the live-UI end-to-end suite (needs tmux + entr; suites skip without them)
make test   # both of the above
```

### End-to-end (live UI) tests

The per-subproject suites source each REPL script and call its functions
directly; they never launch the terminal UI. The suite under
[`tests/`](tests/) closes that gap: it drives each REPL's real three-pane
tmux session and checks that saving the file live-reloads the output. It uses
`ttydrive`, a terminal driver vendored from the [socwrap][socwrap] project
(`tools/ttydrive`), to type into and read back a live session. See
[`tests/README.md`](tests/README.md) for how it works.

[socwrap]: https://github.com/That-Guy-40/socwrap


Attribution
-----------

This collection is based on [awkrepl](https://github.com/ernstki/awkrepl) by
**Kevin Ernst** — the original REPL concept, three-pane tmux layout,
`#DATA`/`#ARGS` file convention, and entr-based event loop all originate
there. Visit the original repo: <https://github.com/ernstki/awkrepl>


License
-------

MIT, as stated in each script's header. (There is no separate `LICENSE` file
in this repository.)
