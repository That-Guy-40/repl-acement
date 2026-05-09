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

All three share the same file conventions:

- Lines after `#DATA` are supplied as input to the tool
- Lines starting with `#ARGS` are passed as command-line flags
- Without `#DATA`, the tool runs on empty/null input


Requirements
------------

- tmux
- [entr](http://eradman.com/entrproject/)
- the relevant tool (`gawk`, `sed`, or `jq`)
- [bat](https://github.com/sharkdp/bat) (optional, syntax highlighting)


Running tests
-------------

Each subproject has its own test suite:

```bash
cd awkrepl && bash tests/smoke/run.sh && bash tests/integration/run.sh
cd sedrepl && bash tests/smoke/run.sh && bash tests/integration/run.sh
cd jqrepl  && bash tests/smoke/run.sh && bash tests/integration/run.sh
```

Or via `make test` inside each subdirectory (sedrepl and jqrepl).


License
-------

MIT. `awkrepl` and `sedrepl` based on work by Kevin Ernst.
