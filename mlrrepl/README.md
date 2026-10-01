mlrrepl
=======

A REPL for [Miller](https://miller.readthedocs.io/) (`mlr`) — the
records-and-fields processor for CSV, TSV, JSON, and other tabular data.
Edit a `.mlr` file in your `$EDITOR` and watch the output update live in a
split tmux window.

Requires [Miller](https://miller.readthedocs.io/) 6 (JSONL auto-detection
uses `--jsonl`, which Miller 5 lacks), [tmux](https://tmux.github.io/),
[entr](http://eradman.com/entrproject/), and `xargs` (findutils; almost
always already present).
[bat](https://github.com/sharkdp/bat) (or Debian/Ubuntu's `batcat`) is
optional but recommended; the source is highlighted as Ruby, which is close
enough for the Miller DSL.

Usage
-----

```
mlrrepl
```

Opens `~/.repl.mlr` (created if missing) in your `$EDITOR` inside a
three-pane tmux layout:

```
┌─────────────────────────────────┐
│  $EDITOR  ~/.repl.mlr           │
├──────────────────┬──────────────┤
│  mlr output      │  source      │
│  (live)          │  preview     │
└──────────────────┴──────────────┘
```

File format
-----------

```
# Miller DSL expression — Miller itself understands # comments
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
```

- Everything above `#DATA` is the Miller DSL (passed via `mlr put -f`).
- Everything below `#DATA` is the input data.
- Without `#DATA`, mlrrepl prints a hint — Miller always needs input.
- `#ARGS` lines inject extra main `mlr` flags, placed before `put` (e.g.
  `#ARGS --tsv` for tab-separated data, or `#ARGS --icsv --ojson`). They are
  split like a shell command line: quotes are honored, nothing is expanded.
- When there is no `#ARGS`, the format is auto-detected from the first data
  line: a line starting with `{` uses `--jsonl`, one containing a comma uses
  `--csv`, and anything else `--nidx`. Any `#ARGS` turns auto-detection off
  entirely, so include a format flag (`#ARGS --ojson` alone would read the
  data as Miller's default DKVP).
- A comment line that begins with `# data` or `# arg` (any case) is taken
  as a `#DATA` / `#ARGS` header, so avoid starting comments that way.

Running with Docker
-------------------

Build the image locally and run it (no prebuilt image is published):

```
make build && make run
```

Tests
-----

```
make test
```

Author
------

Based on [awkrepl](https://github.com/ernstki/awkrepl) by **Kevin Ernst** —
the original REPL concept, three-pane tmux layout, `#DATA`/`#ARGS` file
convention, and entr-based event loop all originate there.

Visit the original repo: <https://github.com/ernstki/awkrepl>
