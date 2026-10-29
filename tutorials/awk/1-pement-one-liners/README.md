Tutorial 1: Pement's one-liners, live
=====================================

Eric Pement's *Handy one-liners for awk* (vendored as
[`../refs/awk1line.txt`](../refs/awk1line.txt)) is the sheet most people
learn their first awk from. This tutorial runs its most useful entries, in
the sheet's order, against one tiny pay ledger, so you see what each
one-liner does to real lines rather than reading what it should do.

```bash
tutorials/awk/1-pement-one-liners/run.sh      # F5: next step, C-b d: leave
```

Each step quotes the one-liner from the sheet, explains it in a few lines
and ends with a `# Try:` suggestion. The editor stays live between steps,
so do try: edit, save, read the output pane, then press F5.

The data
--------

Twelve lines of name, hourly rate and hours, with two blank lines and three
duplicated lines on purpose:

```
Beth    4.00  0
Dan     3.75  0
Kathy   4.00  10

Mark    5.00  20
Mary    5.50  22
Susie   4.25  18
Susie   4.25  18
Beth    4.00  0

Kathy   4.00  10
Mark    5.00  20
```

A few steps bring their own data (negative numbers, coloured words, lines
ending in a backslash) because the ledger has nothing for those one-liners
to do.

The steps
---------

| # | Sheet section | One-liner | What to watch for |
|---|---------------|-----------|-------------------|
| 1 | File spacing | `1;{print ""}` | a pattern with no action prints; two rules run on every line |
| 2 | Numbering | `printf("%5d : %s\n", NR,$0)` | `NR`; `%5d` right-aligns; awkrepl's auto-wrap in the source pane |
| 3 | Numbering | `NF{$0=++a " :" $0};{print}` | `NF` as a truth test; `++a`; assigning to `$0` |
| 4 | Numbering | `END{print NR}` | `END` sees the final `NR` |
| 5 | Calculations | sum fields per line, and overall | a name adds 0; per-line vs. carried variables |
| 6 | Calculations | absolute values | assigning to `$i` rebuilds `$0` |
| 7 | Calculations | `/Beth/{n++}; END{print n+0}` | regex pattern; `n+0` |
| 8 | Calculations | largest value and its line | pattern plus action in one rule |
| 9 | Calculations | `NF` and `$NF` | `$NF` is the last field; blank lines |
| 10 | Calculations | `$NF > 15` | a comparison as a pattern |
| 11 | Conversion | `{$1=$1;print}` | the `$1=$1` trick rebuilds `$0` with single spaces |
| 12 | Conversion | `printf "%30s\n", $0` | width padding |
| 13 | Conversion | `gsub` on selected lines | `sub` vs `gsub`; a pattern limits where |
| 14 | Conversion | reverse lines (tac) | arrays indexed 0..n and a backwards loop |
| 15 | Conversion | join backslash-continued lines | `getline t`; `next` |
| 16 | Conversion | swap and reverse fields | the sheet's field-reversal prints `i`, not `$i` |
| 17 | Conversion | `! a[$0]++` (uniq) | the idiom everyone copies; `length(a)` |
| 18 | Selective printing | line before a match; `tail -2` | remembering the previous line |
| 19 | Selective printing | several regexes; `length > N` | "any of" vs "all of"; `length` of `$0` |
| 20 | Selective printing / deletion | `NR==5,NR==7`; `NF` | range patterns; `NF` deletes blank lines |

Left out: the DOS/Unix newline entries (platform-specific), `print $1 |
"sort"` (needs a pipe to a command; see tutorial 3), and the `ORS=NR%5?","
:"\n"` line-joiner, whose sheet entry has a typo (`%NR` for `NR`).

Verifying
---------

```bash
demo/verify.sh --dir tutorials/awk/1-pement-one-liners/steps
```

plays all twenty steps headless and checks the editor, output and source
panes of each one.
