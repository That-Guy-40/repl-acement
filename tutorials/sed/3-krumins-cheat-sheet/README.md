Tutorial 3: the sed cheat sheet, live
=====================================

A hands-on tour of Peteris Krumins' "Sed Cheat Sheet", vendored at
[`../refs/sed.stream.editor.cheat.sheet.txt`](../refs/sed.stream.editor.cheat.sheet.txt)
(see [`../refs/SOURCES.md`](../refs/SOURCES.md) for provenance). The sheet
is a reference: a table of which commands touch the input stream, the
output stream, the pattern space and the hold buffer, then a command
summary, the GNU extensions, the address forms and the command-line
options. This tutorial takes the sheet section by section and shows each
item doing something small to one eight-line inventory in sedrepl, so the
rows on the sheet become things you have seen run.

Every step is a sedrepl file: narration as `#` comments at the top (sed
accepts them, and sedrepl echoes the whole script into the output pane
above the result), the program, and a `#DATA` block. The output pane shows
the `# command:` line sed was run with, so `#ARGS -n`, `-E` and `-l 14` are
visible where they matter; the right-hand pane shows the script
highlighted. Each step ends with a `# Try:` line, an edit worth making
before moving on.

Running it
----------

```bash
tutorials/sed/3-krumins-cheat-sheet/run.sh      # step by step, in a terminal >= 180x50
```

The driver opens its own tmux session and types each step into vim for
you. After a step's output appears, the editor is yours: edit, save (`:w`),
and the output re-runs. Press `F5` for the next step, `C-b d` to leave.
`run.sh --steps 7,13` plays only those steps.

The data
--------

Eight numbered lines, so line-number addresses, `first~step` and
`addr1,+N` are easy to check by eye:

```
1 apples 12
2 bananas 30
3 cherries 7
4 dates 16
5 figs 25
6 grapes 40
7 kiwis 18
8 lemons 22
```

Step 7 uses four of these lines (its output would not fit otherwise) and
step 13 three; steps 15 and 16 read [`data/note.txt`](data/note.txt), two
lines, by its repo-relative path, since sed runs with the repository root
as its working directory.

The steps
---------

| Step | Sheet section | What to watch for |
|------|---------------|-------------------|
| 1 | Streams: `p`, `-n`; addresses `number`, `$` | with `-n` only `1p` and `$p` reach the output; the `# command:` line shows `-n` |
| 2 | Streams: `n` vs `N` | `N` keeps both lines in the pattern space, so `s/\n/ \| /` joins pairs |
| 3 | Streams: `D` and `P` | `$!N;$!D` is a two-line window that slides to the end: `tail -2` |
| 4 | Hold buffer: `x` | every line prints the previous one; the first is blank and the last is never printed |
| 5 | Hold buffer: `H`, `x` | `/a/H;$!d;x` collects matching lines; the leading `, ` is the empty hold buffer's newline |
| 6 | `=` | the line number comes out on its own line, before `p` |
| 7 | `a\`, `i\`, `c\` | text queued after or before the line; `c` deletes the line it replaces |
| 8 | `s///` flags | `g`, a number, `p`, and `w /dev/stdout` writing the changed lines to the terminal |
| 9 | `s///` groups, `-E` | `\1 \2 \3` reorder the fields, `&` repeats the match; without `-E` the parentheses are literal |
| 10 | `y///` | one-for-one transliteration, no regex, equal-length lists |
| 11 | `b` | lines with an `a` branch past the `s///`; the rest are tagged |
| 12 | `t` | branch only when the `s///` changed something; `\U` upper-cases the group |
| 13 | `l`, `-l N` | tabs show as `\t`, line ends as `$`, and `-l 14` wraps with a `\` |
| 14 | `q`, extension `Q` | `q` prints the line and stops reading; `Q` stops without printing |
| 15 | `r file`, extension `R file` | `r` appends the whole note after the last line, `R` one line of it per match |
| 16 | Extensions `T`, `W file` | `W` writes the first line of a two-line pattern space; `T` branches when `s///` failed |
| 17 | Addresses `first~step`, `addr1,+N`, `addr1,~N` | `1~3p` is lines 1, 4, 7; `/figs/,+1p` is 5 and 6 |
| 18 | Address `0,addr2` | `0,/a/d` deletes only apples; `1,/a/d` would take bananas too |
| 19 | Addresses `/regex/,/regex/`, `\cregexc` | an inclusive range by pattern; `\%kiwis%` is `/kiwis/` with another delimiter |

Left out
--------

- `-i` (in-place editing) and `w`/`W` to real files: sedrepl runs the
  script against a temp copy of the `#DATA` block, so there is nothing
  sensible to edit in place; `w /dev/stdout` shows the mechanism instead.
- `-s` (treat input files separately) and `-u` (unbuffered): both need
  several input files or a pipeline, and sedrepl passes exactly one file.
- `-e`, `-f`, `--help`, `-V`: `-f` is how sedrepl already runs the script
  (see the `# command:` line); the others print no data.

Verifying
---------

```bash
demo/verify.sh --dir tutorials/sed/3-krumins-cheat-sheet/steps
```

plays all nineteen steps headless and checks the editor, output and
source panes of each one (the title in the editor, the expected lines and
the `# command:` line in the output, a token of the script in the source
pane).
