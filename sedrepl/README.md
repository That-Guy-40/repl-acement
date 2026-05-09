sedrepl
=======

A [REPL][1] of sorts for [sed][2].

Syntax-checks and displays your sed code in the right-hand pane when you save
it, and shows the results of your script's execution in the lower-left pane.
The top pane is your text editor (whatever you have `$EDITOR` set to, or
defaults to `nano`), with the file `~/.repl.sed` open for editing.

Any lines after `#DATA` at the end of the file are supplied as input to your
script, for quick testing on sample inputs. If you have a line in your source
file that starts with `#ARGS`, anything on the line after that is provided as
command-line arguments to your script (such as `-n` to suppress automatic
printing). _Whitespace within individual arguments is probably not preserved,
though._

Unlike `awkrepl` (the AWK version on which this is based), sed operates on
every line of input by default, so no automatic wrapping of your code is
necessary — what you write is what sed runs.


Requirements
------------

- tmux
- [entr][]
- sed (GNU or BSD)
- [bat][] (optional, for syntax-highlighted output)


Usage
-----

Make the `sedrepl` script executable with `chmod a+x` (if it's not already) and
put it somewhere in your search path, like `$HOME/bin`. Run `sedrepl`.

The [`examples.sed`](examples.sed) from this repository is copied to
`~/.repl.sed` in the Docker container, to provide you with some working
examples to play with. Just clear out the entire contents of this file and
replace with your own code when you get bored with those examples.

### Using a different editor

The `EDITOR` environment variable is respected, defaulting to `nano` if not set:

```bash
EDITOR=vim sedrepl
```


### `#DATA` section

Append `#DATA` at the end of your sed script to supply test input:

```sed
s/foo/bar/

#DATA
foo
bar
baz
```

### `#ARGS` section

Use `#ARGS` to pass flags to sed. For example, to suppress automatic printing
and only output lines explicitly matched with `p`:

```sed
#ARGS -n
/^chr8/p

#DATA
chr1	100	200
chr8	50	75
```

### `#ARGS` and `#DATA` together

Use both `#ARGS` and `#DATA` in any order, but typically `#ARGS` comes first:

```sed
#ARGS -n
s/chr/CHR/
p

#DATA
chr1	100	200
chr8	50	75
```


Bugs
----

Please report any issues on the [issue tracker][issues].


See also
--------

- <https://en.wikipedia.org/wiki/Sed>
- <https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop>
- <https://www.gnu.org/software/sed/manual/sed.html>


Author
------

Based on [awkrepl](https://github.com/ernstki/awkrepl) by **Kevin Ernst** —
the original REPL concept, three-pane tmux layout, `#DATA`/`#ARGS` file
convention, and entr-based event loop all originate there.

Visit the original repo: <https://github.com/ernstki/awkrepl>


License
-------

MIT.


[1]: https://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop
[2]: https://en.wikipedia.org/wiki/Sed
[entr]: http://eradman.com/entrproject/
[bat]: https://github.com/sharkdp/bat
[issues]: https://github.com/ernstki/awkrepl/issues
