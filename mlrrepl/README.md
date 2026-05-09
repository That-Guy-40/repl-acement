mlrrepl
=======

A REPL for [Miller](https://miller.readthedocs.io/) (`mlr`) — the
records-and-fields processor for CSV, TSV, JSON, and other tabular data.
Edit a `.mlr` file in your `$EDITOR` and watch the output update live in a
split tmux window.

Requires [Miller](https://miller.readthedocs.io/) ≥ 5,
[tmux](https://tmux.github.io/), and
[entr](http://eradman.com/entrproject/).
[bat](https://github.com/sharkdp/bat) is optional but recommended.

Usage
-----

```
mlrrepl [replfile]
```

Opens `~/.repl.mlr` (or a file you specify) in your `$EDITOR` inside a
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
# Miller DSL expression — standard # comments are preserved
$total = $quantity * $price

#DATA
name,quantity,price
apples,3,1.20
bananas,5,0.50
```

- Everything above `#DATA` is the Miller DSL (passed via `mlr put -f`).
- Everything below `#DATA` is the input data.
- Without `#DATA`, mlrrepl prints a hint — Miller always needs input.
- `#ARGS` lines inject extra `mlr` flags (e.g. `#ARGS --tsv` to change the
  input/output format from the default CSV).
- The format is auto-detected: CSV data (comma in header row) uses `--csv`;
  everything else defaults to `--nidx`.  `#ARGS` overrides.

Running with Docker
-------------------

```
docker run -it ernstki/mlrrepl
```

Or build locally:

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

Inspired by [awkrepl](https://github.com/ernstki/awkrepl) by Kevin Ernst —
the original REPL concept, three-pane layout, `#DATA`/`#ARGS` convention,
and entr-based event loop all originate there.

- <https://github.com/ernstki/awkrepl>
