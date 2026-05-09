yqrepl
======

A REPL for [yq](https://github.com/mikefarah/yq) — the YAML/JSON/TOML
processor.  Edit a `.yq` file in your `$EDITOR` and watch the output update
live in a split tmux window.

Requires [yq](https://github.com/mikefarah/yq) ≥ 4 (Mike Farah's Go
implementation), [tmux](https://tmux.github.io/), and
[entr](http://eradman.com/entrproject/).
[bat](https://github.com/sharkdp/bat) is optional but recommended for
syntax-highlighted source preview.

Usage
-----

```
yqrepl [replfile]
```

Opens `~/.repl.yq` (or a file you specify) in your `$EDITOR` inside a
three-pane tmux layout:

```
┌─────────────────────────────────┐
│  $EDITOR  ~/.repl.yq            │
├──────────────────┬──────────────┤
│  yq output       │  source      │
│  (live)          │  preview     │
└──────────────────┴──────────────┘
```

File format
-----------

```yaml
# yq expression goes here — standard YAML comments are preserved
.[] | .name

#DATA
- name: Alice
  age: 30
- name: Bob
  age: 17
```

- Everything above `#DATA` is the yq expression.
- Everything below `#DATA` is piped as input to yq.
- Without `#DATA`, yq runs with `--null-input` — good for generating YAML
  from scratch (e.g. `{"greeting": "hello"}`).
- `#ARGS` lines inject extra yq flags (e.g. `#ARGS -o json` to emit JSON).

Running with Docker
-------------------

```
docker run -it ernstki/yqrepl
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

Based on [awkrepl](https://github.com/ernstki/awkrepl) by **Kevin Ernst** —
the original REPL concept, three-pane tmux layout, `#DATA`/`#ARGS` file
convention, and entr-based event loop all originate there.

Visit the original repo: <https://github.com/ernstki/awkrepl>
