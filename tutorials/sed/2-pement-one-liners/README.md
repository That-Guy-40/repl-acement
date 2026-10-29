Tutorial 2: Pement's sed one-liners, live
=========================================

Eric Pement's *Useful one-line scripts for sed* (version 5.5, vendored as
[`../refs/sed1line.txt`](../refs/sed1line.txt)) is the sheet most people
keep next to the terminal. This tutorial runs its entries, in the sheet's
order, against one tiny list of US states, so you see what each one-liner
does to real lines rather than reading what it should do.

```bash
tutorials/sed/2-pement-one-liners/run.sh      # F5: next step, C-b d: leave
```

Each step quotes the one-liner from the sheet, explains it in a few lines
and ends with a `# Try:` suggestion. The editor stays live between steps,
so do try: edit, save, read the output pane, then press F5.

Unlike awkrepl, sedrepl echoes the whole script, comments included, into
the output pane above sed's result, so the narration is visible in both
top and bottom-left panes; the result is what follows the blank line.

The data
--------

Five to seven state names, alphabetical, with blank lines or duplicates
added where the one-liner needs them:

```
Alabama
Alaska
Iowa
Kansas
Montana
```

A few steps bring their own data (a sentence with several `a`s, coloured
words, lines ending in a backslash, big numbers, a mail header, HTML)
because the list has nothing for those one-liners to do.

The steps
---------

| # | Sheet section | One-liner | What to watch for |
|---|---------------|-----------|-------------------|
| 1 | File spacing | `G` | the empty hold space appended to every line |
| 2 | File spacing | `/^$/d;G` | an address before a command; `d` ends the cycle |
| 3 | File spacing | `n;d` | `n` prints and reads on; every second line goes |
| 4 | File spacing | `/regex/{x;p;x;}` | `{}` groups; `x` swaps the hold space in and out |
| 5 | Numbering | `=` | line numbers on their own lines; the sheet's second pass |
| 6 | Conversion | `s/^[ \t]*//;s/[ \t]*$//` | two substitutions; a `|` marker shows the trailing run went |
| 7 | Conversion | `:a;s/^.\{1,78\}$/ &/;ta` | a label, `&`, and a `t` loop that pads until the width is reached |
| 8 | Conversion | `s/foo/bar/`, `/4`, `/g` | first, Nth, every match; a line-number address per form |
| 9 | Conversion | `/baz/!s/foo/bar/g` | `!` negates an address |
| 10 | Conversion | `s/scarlet\|ruby\|puce/red/g` | GNU `\|` alternation |
| 11 | Conversion | `1!G;h;$!d` (tac) | hold space as an accumulator; the last line is the whole file |
| 12 | Conversion | `$!N;s/\n/ /` (paste) | `N` joins two lines; the embedded `\n` |
| 13 | Conversion | `:a;/\\$/N;s/\\\n//;ta` | backslash continuation; `\\` for a literal backslash |
| 14 | Conversion | `:a;s/\B[0-9]\{3\}\>/,&/;ta` | `\B`, `\>`, and a loop that stops by itself |
| 15 | Selective printing | `10q` (head) | `q` stops reading early |
| 16 | Selective printing | `$!N;$!D` (tail -2) | a two-line window sliding down the file |
| 17 | Selective printing | `-n '/regexp/p'` (grep) | `#ARGS -n` shows up in the `# command:` line |
| 18 | Selective printing | `-n '/regexp/{g;1!p;};h'` | the line before a match; `h` every cycle |
| 19 | Selective printing | `/AAA/!d; /BBB/!d` | "and" as two deletions |
| 20 | Selective printing | `/./{H;$!d;};x;/AAA/!d` | whole paragraphs collected with `H` |
| 21 | Selective printing | `-n '/^.\{65\}/p'` | length as a regex |
| 22 | Selective printing | `-n '/Iowa/,/Montana/p'` | a range of two patterns |
| 23 | Selective deletion | `$!N; s/^\(.*\)\n\1$/\1/; t; D` (uniq -d) | a back-reference across the newline |
| 24 | Selective deletion | `N;$!P;$!D;$d` | the tail window run the other way |
| 25 | Selective deletion | `/./,/^$/!d` (cat -s) | a range used to delete what is outside it |
| 26 | Special applications | `/^Subject: */!d; s///;q` | the empty regex reuses the last one |
| 27 | Special applications | `:a;s/<[^>]*>//g;/</N;//ba` | a loop that pulls in lines until the tag closes |

Left out: the DOS/Unix newline entries (platform-specific), the entries
that need a second process (`sed = file | sed ...`, the paragraph sort,
uudecode) and the DOS zip batch file. The sheet's remaining variants are
mentioned in the comments of the nearest step.

Verifying
---------

```bash
demo/verify.sh --dir tutorials/sed/2-pement-one-liners/steps
```

plays all twenty-seven steps headless and checks the editor, output and
source panes of each one.
