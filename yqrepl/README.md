yqrepl
======

A REPL for [yq](https://github.com/mikefarah/yq) — the YAML/JSON/TOML
processor.  Edit a `.yq` file in your `$EDITOR` and watch the output update
live in a split tmux window.

Requires [yq](https://github.com/mikefarah/yq) v4 (Mike Farah's Go
implementation), [tmux](https://tmux.github.io/),
[entr](http://eradman.com/entrproject/), `sed` (GNU sed or BSD sed; used to
split the REPL file), and `xargs` (findutils; almost always already present).
[bat](https://github.com/sharkdp/bat) (or Debian/Ubuntu's `batcat`) is
optional but recommended for syntax-highlighted source preview.

**Which yq?** There are two unrelated tools called `yq`. yqrepl needs Mike
Farah's; `yq --version` should mention `github.com/mikefarah/yq`. The Python
`yq` (a jq wrapper, which is what `apt install yq` gives you on
Debian/Ubuntu) has a different grammar, so yqrepl refuses to launch with it
and prints which `yq` it found instead.

Usage
-----

```
yqrepl
```

Opens `~/.repl.yq` (created if missing) in your `$EDITOR` inside a
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
# yq expression goes here — # comment lines stay in the file
.[] | .name

#DATA
- name: Alice
  age: 30
- name: Bob
  age: 17
```

- Everything above `#DATA` is the yq expression. Whole-line `#` comments
  and blank lines are stripped before it is run as `yq eval "<expr>"`;
  they stay in your file and in the source preview.
- Everything below `#DATA` is written to a temp file that yq reads as its
  input.
- Without `#DATA`, yq runs with `--null-input` — good for generating YAML
  from scratch (e.g. `{"greeting": "hello"}`).
- `#ARGS` lines above `#DATA` inject extra yq flags (e.g. `#ARGS -o json` to
  emit JSON); an `#ARGS` line below `#DATA` is just another line of data.
  They are split like a shell command line: quotes are honored (so a value
  may contain spaces), but nothing is expanded — no globs or variables.
  If the line has an unmatched quote (say, `it's`), a warning is shown in
  the output pane and the line is split on whitespace instead, with the
  quote characters kept as typed.
- Headers are case-insensitive and may take a colon. `#DATA` must be alone
  on its line; `#ARGS` (or `#ARG`, `#ARGUMENT`, `#ARGUMENTS`) must be
  followed by nothing or by options, the first of which starts with `-`
  (e.g. `#ARGS -o json`, `#args: -o yaml`). Any other comment, such as `# Database records`
  or `# Args are cool`, is just a comment.

Running with Docker
-------------------

Build the image locally and run it (no prebuilt image is published):

```
make build && make run
```

To push your build to Docker Hub, run `make publish DOCKER_HUB_USER=you`
(tagged `you/yqrepl`).

The image downloads the latest `yq_linux_amd64` release binary, so it
targets x86-64 hosts.

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
