Tutorial 2: AWK from the ground up (after the Grymoire tutorial)
================================================================

A beginner's walk through AWK in 21 steps, in the order Bruce Barnett's
["Awk" tutorial on Grymoire](https://www.grymoire.com/Unix/Awk.html)
teaches it: structure, fields and the built-in variables, arrays, printf,
flow control, functions, getline, and the pattern forms. Read his page in
a browser alongside this; it is not vendored here because its terms do not
allow electronic copies (see [`../refs/SOURCES.md`](../refs/SOURCES.md)).
Everything in this directory is original: its own narration and examples.

Most steps work on the same small fake `ls -l` listing (a `total` line
plus eight files owned by alice, bob, carol and dave), so you can watch the
same data answer different questions. Steps 7 and 8 use a short
passwd-style list, step 11 a few blank-line-separated addresses.

Running it
----------

```bash
tutorials/awk/2-grymoire-tutorial/run.sh      # step by step, in a terminal >= 180x50
```

Each step is typed into the editor for you and saved; the result appears in
the bottom-left pane and gawk's pretty-printed view of the program in the
bottom-right. Then the editor is yours: every step ends with a `# Try:`
suggestion, and saving re-runs the program. Press **F5** for the next step
(it replaces the buffer), `C-b d` to leave.

```bash
demo/verify.sh --dir tutorials/awk/2-grymoire-tutorial/steps   # headless check of every pane
```

Steps
-----

| Step | Topic | What to watch for |
|------|-------|-------------------|
| 1 | pattern `{ action }`, fields | `$9` is the file name; no pattern means every line |
| 2 | BEGIN and END | the heading prints before any data, the counts after |
| 3 | how a program file runs | the dimmed `# command:` line shows `gawk -f` and the data file |
| 4 | `-v name=value` | `#ARGS -v limit=5000` appears on the command line; change it and the filter changes |
| 5 | arithmetic, `+=`, `++`, `int()` | the average without `int()` would be 35019.2 |
| 6 | comparison, regex and `&&` patterns | one line can match several rules |
| 7 | FS | colons split a passwd line; `$7` is the shell |
| 8 | OFS | `print a, b` joins with OFS; `$0` is untouched until a field is assigned |
| 9 | NF and `$NF` | the `total` line has 2 fields, the others 9 |
| 10 | NR | renumbering with `NR - 1`; NR in END is the line count |
| 11 | RS and ORS | paragraph mode: each address is one record with 6 or 7 words |
| 12 | associative arrays | bytes per owner; `PROCINFO["sorted_in"]` for a stable order |
| 13 | two-dimensional keys | `count[$3, $4]` and `split(key, part, SUBSEP)` |
| 14 | printf | `%-12s` left-justified names, `%8d` right-aligned sizes, `%5.1f` |
| 15 | next and exit | the `total` line is skipped, nothing after dave is checked, END still runs |
| 16 | int, sqrt, `^`, `%`, rand/srand | `int(-7.9)` is -7, not -8 |
| 17 | length, index, substr, toupper | capitalising a word |
| 18 | split, sub, gsub, match | the extension via RSTART/RLENGTH; vowels starred |
| 19 | getline | from a pipe in BEGIN, and the next line inside a rule |
| 20 | user-defined functions | extra parameters as locals; `sprintf` |
| 21 | range patterns | `/notes/,/deploy/` prints lines 2 to 5 |

Files
-----

| Path | What it is |
|------|------------|
| `run.sh` | starts the tutorial interactively (`demo/play.sh --dir steps --interactive`) |
| `steps/NN_*.repl` | one step each: `#>` directives for the driver and verifier, then what is typed into the editor |
