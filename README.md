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

- Lines after a `#DATA` line are supplied as input to the tool. `#DATA` must
  be alone on its line (optionally followed by a colon and/or whitespace)
- A `#ARGS` line passes the options after it as command-line flags, e.g.
  `#ARGS -n` or `#args: --csv`. `#ARG`, `#ARGUMENT` and `#ARGUMENTS` work too.
  The header must be followed by nothing or by options whose first one starts
  with `-` (later ones need not)
- Both headers are case-insensitive, must start with `#` in the first column,
  and may have whitespace between the `#` and the word; a colon after the word
  is optional. Any other line is an ordinary comment, so `# Database…`,
  `# data comes from…` or `# Args are cool` neither split the file nor add
  arguments
- Without `#DATA`: `awkrepl` and `sedrepl` run against an empty data file,
  `jqrepl` runs `jq -n` and `yqrepl` runs `yq eval --null-input` (null input),
  `perlrepl` runs the script once with no input file, and `mlrrepl` prints a
  hint instead of running

**Comment handling**: `awkrepl` strips whole-line `#` comments and blank lines
from the source before passing it to `gawk`. `yqrepl` likewise drops
whole-line comments and blank lines from the expression it passes to `yq`
(the panes still show them). `sedrepl`, `jqrepl`, `mlrrepl` and `perlrepl`
pass comments through unchanged — their tools support `#` natively.

**Auto-wrap**: `awkrepl` wraps a bare program such as `print $1` or
`printa(arr)` in `{ }` when there is `#DATA`, or in `END { }` when there
isn't. `gawk` checks the whole program both ways (`gawk --pretty-print`, which
only parses it and never runs it). Rules with actions, function definitions
and `BEGIN`/`END` blocks parse only as written, so they're left alone;
statements such as `print $1` parse only when wrapped, so they're wrapped; if
neither parses, the program is left as written, so the error is about your own
code. A bare expression parses both ways: one that starts like a pattern
(`!/re/`, `$NF > 3`, `NR == 1`, …) or compares or matches something stays a
pattern, while one that starts with a name (`x = 3`, `printa(arr)`, `i++`) is
wrapped as a statement. `perlrepl` detects bare per-line expressions and adds
`-n` automatically when there is `#DATA`.

**`#ARGS` quoting**: `#ARGS` is parsed with shell-style quoting, so a value
that contains spaces must be quoted — `#ARGS -v "greeting=hello world"` is one
argument, while `#ARGS -v greeting=hello world` is three. Quotes and
backslash escapes are the only things interpreted: a `*` or other glob
character is passed through literally and is never expanded against the
working directory. An unmatched quote (e.g. `#ARGS -v msg=it's`) prints a
warning in the output pane, and the arguments are then split on whitespace with
the quote characters kept as typed (still without globbing).

**`yq` flavor**: `yqrepl` requires [Mike Farah's Go `yq`][yq-mf]. The unrelated
Python `yq` (a jq wrapper) uses a different grammar; `yqrepl` detects it and
refuses to launch with a clear message rather than failing cryptically.

**Temp files and tmux**: each REPL keeps its scratch files under `$TMPDIR`
(default `/tmp`). The editor pane runs a small generated wrapper around
`$EDITOR`: when the editor exits, or the REPL's window is killed, it removes
the temp files and closes only the REPL's own window. If either bottom pane's
`entr` exits, that pane closes the same window too. The REPLs install no tmux
hooks. Started outside tmux, a REPL opens a new session named
`<tool>repl-<pid>`, which ends when you quit the editor. Detaching (`C-b d`)
does not end it: it keeps running with its files, and you can reattach with
`tmux attach -t <tool>repl-<pid>`. Started from inside an existing tmux
session, a REPL opens as a new window in that session; panes exiting in your
other windows don't affect it, and quitting it leaves your other windows
alone.

[yq-mf]: https://github.com/mikefarah/yq


Requirements
------------

- bash
- tmux
- [entr](http://eradman.com/entrproject/)
- the relevant tool (`gawk`, `sed`, `jq`, [Mike Farah's `yq`][yq-mf], `mlr`, `perl`)
- `sed` (every REPL uses it to split the file at `#DATA`/`#ARGS`)
- `perl` only for `perlrepl` itself, and for `make help` (the root and every
  subproject `Makefile` use it to list the targets)
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
