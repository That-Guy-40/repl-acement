jqrepl
======

A [REPL][1] of sorts for [jq][2].

Displays your jq filter in the right-hand pane when you save it, and shows the
results of your filter's execution in the lower-left pane. The top pane is your
text editor (whatever you have `$EDITOR` set to, or defaults to `nano`), with
the file `~/.repl.jq` open for editing.

Any lines after `#DATA` at the end of the file are supplied as JSON input to
your filter, for quick testing on sample inputs. If you have a line in your
source file that starts with `#ARGS`, anything on the line after that is
provided as command-line arguments to `jq` (such as `-r` for raw string
output). _Whitespace within individual arguments is probably not preserved,
though._

If there is no `#DATA` section, `jq` runs with `--null-input` (`-n`) so the
filter is evaluated against `null` rather than blocking on stdin — useful for
constructing JSON from scratch or trying built-in functions.


Requirements
------------

* Docker
* _—or—_ tmux, [entr][], jq, and Perl
    * also [bat][], if you want your jq filter source to be syntax-highlighted


Usage
-----

If you have all the prereqs and want to run it without Docker, make the
`jqrepl` script executable with `chmod a+x` (if it's not already) and put it
somewhere in your search path, like `$HOME/bin`. Run `jqrepl`.

Otherwise, for Docker:

```bash
make build
# or, if you don't have 'make'
docker build -t jqrepl .

make run
# or
docker run -it --rm jqrepl
```

The [`examples.jq`](examples.jq) from this repository is copied to
`~/.repl.jq` in the Docker container, to provide you with some working
examples to play with. Just clear out the entire contents of this file and
replace with your own filter when you get bored with those examples.

### Using a different editor

The `EDITOR` environment variable is respected, defaulting to `nano` if not set:

```bash
EDITOR=vim jqrepl
# or
make run EDITOR=vim
```


### `#DATA` section

Append `#DATA` at the end of your filter to supply test input:

```jq
.[] | .name

#DATA
[
  {"name": "Alice", "age": 30},
  {"name": "Bob",   "age": 17}
]
```

The JSON data can span multiple lines; `jq` receives the entire block after
`#DATA` as its input file.

### `#ARGS` section

Use `#ARGS` to pass flags to `jq`. For example, to output raw strings instead
of JSON-encoded ones:

```jq
#ARGS -r
.[] | .name

#DATA
[{"name": "Alice"}, {"name": "Bob"}]
```

Or to bind a variable:

```jq
#ARGS --arg threshold 25
.[] | select(.age > ($threshold | tonumber)) | .name

#DATA
[
  {"name": "Alice", "age": 30},
  {"name": "Bob",   "age": 17}
]
```

### No `#DATA` — null-input mode

Without a `#DATA` section, `jq` runs with `-n` so the filter receives `null`
as input. This is handy for building JSON from scratch or exploring built-in
functions:

```jq
{greeting: "hello", nums: [range(5)]}
```

```jq
now | todate
```


Differences from `awkrepl`
--------------------------

* No automatic wrapping of bare expressions — jq filters are already
  complete programs.
* No AWK helper functions (`printa`, `printaa`, etc.).
* Without `#DATA`, jq runs in `--null-input` mode rather than wrapping in
  `END {}`.
* `#` comments in the filter source are preserved (jq supports them natively
  in filter files).


Bugs
----

Please [report any issues][issues] you find.


See also
--------

* <https://jqlang.github.io/jq/>
* <https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop>
* <https://jqplay.org/>


Author
------

Inspired by [awkrepl](https://github.com/ernstki/awkrepl) by Kevin Ernst —
the original REPL concept, three-pane layout, `#DATA`/`#ARGS` convention,
and entr-based event loop all originate there.

- <https://github.com/ernstki/awkrepl>


License
-------

MIT.


[1]: https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop
[2]: https://jqlang.github.io/jq/
[entr]: http://eradman.com/entrproject/
[bat]: https://github.com/sharkdp/bat
[issues]: https://github.com/ernstki/awkrepl/issues
