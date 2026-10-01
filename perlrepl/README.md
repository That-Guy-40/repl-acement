perlrepl
========

A REPL for [Perl](https://www.perl.org/) — the duct tape of the internet.
Edit a `.pl` file in your `$EDITOR` and watch the output update live in a
split tmux window.

This is the punchline that awkrepl's own README set up:

> "the whole script probably should've just been written in Perl."

Requires Perl ≥ 5, [tmux](https://tmux.github.io/),
[entr](http://eradman.com/entrproject/), and `xargs` (findutils; almost
always already present).
[bat](https://github.com/sharkdp/bat) (or Debian/Ubuntu's `batcat`) is
optional but recommended for syntax-highlighted source preview.

Usage
-----

```
perlrepl
```

Opens `~/.repl.pl` (created if missing) in your `$EDITOR` inside a
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
# perlrepl expression — Perl itself understands # comments
chomp; print uc($_) . "\n";

#DATA
hello world
foo bar
```

- Everything above `#DATA` is the Perl source.
- Everything below `#DATA` is the input data.
- Without `#DATA`, the script runs with no input file and no automatic
  `-n` — good for self-contained scripts.
- `#ARGS` lines inject extra `perl` switches, placed before the script
  (e.g. `#ARGS -l` for automatic line-ending handling, or `#ARGS -a` for
  auto-split). They are split like a shell command line: quotes are
  honored, nothing is expanded.
  If the line has an unmatched quote (say, `it's`), a warning is shown in
  the output pane and the line is split on whitespace instead, with the
  quote characters kept as typed.
- **Auto-wrap heuristic**: if the first non-blank, non-comment line doesn't
  start with `BEGIN`, `END`, `sub`, `use`, `require`, `package`, `for`,
  `foreach`, `while`, `if`, `unless`, `my`, `our`, or `local`, the source is
  treated as a bare per-line expression and `-n` is added automatically
  when there is data — giving you the AWK-like record loop without the
  boilerplate.
- Headers are case-insensitive and may take a colon. `#DATA` must be alone
  on its line; `#ARGS` (or `#ARG`, `#ARGUMENT`, `#ARGUMENTS`) must be
  followed by nothing or by options, the first of which starts with `-`
  (e.g. `#ARGS -l`, `#args: -a`). Any other comment, such as `# Database records`
  or `# Args are cool`, is just a comment.

Running with Docker
-------------------

Build the image locally and run it (no prebuilt image is published):

```
make build && make run
```

To push your build to Docker Hub, run `make publish DOCKER_HUB_USER=you`
(tagged `you/perlrepl`).

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
