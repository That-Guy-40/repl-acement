repl-acement
============

A collection of interactive REPLs for classic Unix text-processing tools.
Each one opens a three-pane tmux session: editor on top, output bottom-left,
formatted source bottom-right. Save the file; results appear immediately.

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
- Without `#DATA`, the tool runs on empty/null input (or prints a hint for mlrrepl)

**Comment handling**: `awkrepl` strips `#` comments before passing source to
`gawk` (since AWK doesn't support them). All other REPLs preserve comments —
their respective tools support `#` natively.

**Auto-wrap**: `awkrepl` wraps bare expressions in `{ }` or `END { }` blocks;
`perlrepl` detects bare per-line expressions and adds `-n` automatically.


Requirements
------------

- tmux
- [entr](http://eradman.com/entrproject/)
- the relevant tool (`gawk`, `sed`, `jq`, `yq`, `mlr`, `perl`)
- [bat](https://github.com/sharkdp/bat) (optional, syntax highlighting)


Running tests
-------------

Each subproject has its own smoke + integration suite:

```bash
cd awkrepl  && make test
cd sedrepl  && make test
cd jqrepl   && make test
cd yqrepl   && make test
cd mlrrepl  && make test   # requires miller (apt install miller)
cd perlrepl && make test
```

From the repo root, `make` drives all of them plus the end-to-end suite:

```bash
make unit   # every subproject's smoke + integration suites
make e2e    # the live-UI end-to-end suite (needs tmux + entr)
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

MIT.
