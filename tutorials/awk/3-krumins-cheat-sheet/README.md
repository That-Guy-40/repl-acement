Tutorial 3: the AWK cheat sheet, live
=====================================

A hands-on tour of Peteris Krumins' "AWK Cheat Sheet" (v1.17), vendored at
[`../refs/awk.cheat.sheet.txt`](../refs/awk.cheat.sheet.txt) (see
[`../refs/SOURCES.md`](../refs/SOURCES.md) for provenance). The sheet is a
reference: tables of predefined variables, I/O statements, and the
numeric, bit, string and time functions, each with a one-line description
and which awk (original, nawk, gawk) supports it. This tutorial takes the
sheet section by section and shows every item doing something small in
awkrepl, so the one-liners on the sheet become things you have seen run.

Every step is an awkrepl file: narration as `#` comments at the top (awkrepl
strips them before gawk sees the program), the program, and where needed a
`#DATA` block of a few rows. The output pane shows the `# command:` line
gawk was run with and the result; the right-hand pane shows gawk's
pretty-printed view of the program. Each step ends with a `# Try:` line,
an edit worth making before moving on.

Running it
----------

```bash
tutorials/awk/3-krumins-cheat-sheet/run.sh      # step by step, in a terminal >= 180x50
```

The driver opens its own tmux session and types each step into vim for
you. After a step's output appears, the editor is yours: edit, save (`:w`),
and the output re-runs. Press `F5` for the next step, `C-b d` to leave.
`run.sh --steps 7,13` plays only those steps.

```bash
demo/verify.sh --dir tutorials/awk/3-krumins-cheat-sheet/steps
```

runs the whole tutorial headless and checks all three panes of every step
(the title in the editor, the expected lines and the `# command:` line in
the output, a token of the program in the source pane).

The steps
---------

| Step | Sheet section | What to watch for |
|------|---------------|-------------------|
| 1 | Predefined variables: FS, OFS | `#ARGS -F:` sets FS on the command line; OFS is what `print a, b` puts between fields |
| 2 | NF, NR | `NF` alone as a pattern skips the blank line; NR still counts it |
| 3 | RS, ORS, RT | a regex RS turns one line into three records; RT shows which separator matched |
| 4 | ARGC, ARGV, FILENAME, FNR | ARGC is 2, ARGV[0] is `gawk`, ARGV[1] is awkrepl's data file |
| 5 | SUBSEP | `sales[$1, $2]` is one string key; `split(k, p, SUBSEP)` takes it apart; `PROCINFO["sorted_in"]` orders for-in |
| 6 | RSTART, RLENGTH | `match()` as a pattern; `substr($0, RSTART, RLENGTH)` is the matched text |
| 7 | OFMT, CONVFMT | print rounds with OFMT, number-to-string with CONVFMT, integers with neither |
| 8 | ENVIRON, IGNORECASE | `("PATH" in ENVIRON)`; IGNORECASE makes `/hello/` match three lines |
| 9 | FIELDWIDTHS | fixed-width columns with no separator at all |
| 10 | Command line summary: -v, -F | `#ARGS -v rate=1.25 -F,`, visible on the `# command:` line |
| 11 | I/O: `print \| cmd`, `close()`, `/dev/stderr` | the END line prints after the sorted names only because of `close("sort")` |
| 12 | I/O: getline forms | `getline var < file` in BEGIN reads ahead; bare `getline` steps over a comment line |
| 13 | Numeric functions | `int` truncates toward zero; `atan2(0,-1)` is pi; `srand()` returns the old seed |
| 14 | Bit manipulation functions | `and`, `or`, `xor`, `lshift`, `rshift`, `compl`, with a tiny binary printer |
| 15 | String functions, part 1 | `length`, `substr`, `index`, `split`, `toupper`, `sprintf` widths |
| 16 | String functions, part 2 | `sub` vs `gsub` (count, in place) vs `gensub` (returns, backreferences); `strtonum` |
| 17 | String functions: asort, asorti | sorting by value and by key; `PROCINFO["sorted_in"]` as the alternative |
| 18 | Time functions | `strftime` with a fixed timestamp in UTC, `mktime` arithmetic, `systime` |

Everything prints deterministically (fixed timestamps in UTC, `srand(1)`,
no reliance on the environment beyond `PATH` existing), so the verifier can
pin the exact lines.
