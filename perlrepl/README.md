perlrepl
========

A REPL for [Perl](https://www.perl.org/) — the duct tape of the internet.
Edit a `.pl` file in your `$EDITOR` and watch the output update live in a
split tmux window.

This is the punchline that awkrepl's own README set up:

> "the whole script probably should've just been written in Perl."

Requires Perl ≥ 5, [tmux](https://tmux.github.io/), and
[entr](http://eradman.com/entrproject/).
[bat](https://github.com/sharkdp/bat) is optional but recommended for
syntax-highlighted source preview.

Usage
-----

```
perlrepl [replfile]
```

Opens `~/.repl.pl` (or a file you specify) in your `$EDITOR` inside a
three-pane tmux layout:

```
┌─────────────────────────────────┐
│  $EDITOR  ~/.repl.pl            │
├──────────────────┬──────────────┤
│  perl output     │  source      │
│  (live)          │  preview     │
└──────────────────┴──────────────┘
```

File format
-----------

```perl
# perlrepl expression — standard # comments are preserved
chomp; print uc($_) . "\n";

#DATA
hello world
foo bar
```

- Everything above `#DATA` is the Perl source.
- Everything below `#DATA` is the input data.
- Without `#DATA`, the script runs without arguments — good for
  self-contained scripts.
- `#ARGS` lines inject extra `perl` flags (e.g. `#ARGS -l` for automatic
  line-ending handling, or `#ARGS -a` for auto-split).
- **Auto-wrap heuristic**: if the source looks like a bare per-line
  expression (doesn't start with `BEGIN`, `END`, `sub`, `for`, etc.),
  `-n` is added automatically when there is data — giving you the AWK-like
  record loop without the boilerplate.

Running with Docker
-------------------

```
docker run -it ernstki/perlrepl
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
