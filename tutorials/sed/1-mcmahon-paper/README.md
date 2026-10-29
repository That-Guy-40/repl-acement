Tutorial 1: McMahon's paper, live
=================================

Lee E. McMahon wrote sed at Bell Labs in 1974 and described it in *SED --
A Non-interactive Text Editor* (August 1978), the paper shipped as part of
Volume 2 of the Seventh Edition UNIX manual. It is short, exact, and every
example in it runs on the same five lines of Coleridge. The paper is
vendored as troff source, [`../refs/mcmahon-sed.ms`](../refs/mcmahon-sed.ms),
and as a browser-readable rendering,
[`../refs/mcmahon-sed.html`](../refs/mcmahon-sed.html); see
[`../refs/SOURCES.md`](../refs/SOURCES.md) for provenance.

This tutorial walks the paper section by section in `sedrepl`, running its
own examples where it gives them (`2q`, the `n; a\; d` list,
`s/to/by/w`, `s/[.,;?:]/*P&*/gp`, the `r note1` example, the hold-space
example) and a small example of our own where it only describes a function.

```bash
tutorials/sed/1-mcmahon-paper/run.sh      # F5: next step, C-b d: leave
```

Each step quotes the section of the paper it comes from, explains in a
few lines what the commands do to these five lines, and ends with a
`# Try:` suggestion. The editor stays live between steps: edit, save, read
the output pane, then press F5.

The data
--------

The paper's sample text, used by every step:

```
In Xanadu did Kubla Khan
A stately pleasure dome decree:
Where Alph, the sacred river, ran
Through caverns measureless to man
Down to a sunless sea.
```

Step 14 also reads [`data/note1`](data/note1), the three-line note from
the paper's `r` example.

The steps
---------

| # | Paper | Commands | What to watch for |
|---|-------|----------|-------------------|
| 1 | 1, 1.4 | `2q` | sed copies input to output; one address and a function |
| 2 | 1.1 | `#ARGS -n`, `/an/p` | the nocopy flag; a context address; `# command:` shows `-n` |
| 3 | 1.2 | `s/sea/SEA/`, `s/SEA/ocean/` | commands run in order; each sees the last one's output |
| 4 | 2.1 | `1d`, `$s/\.$/!/` | line-number addresses; `$` is the last line |
| 5 | 2.2, 2.3 | `/\./`, `/an.*an/`, `/an/` tagging lines | which lines a pattern selects; the paper's address examples |
| 6 | 2.2 | `/^[AT]/p`, `/\(an\).*\1/p`, `/\.$/p` | bracket sets, `\( \)` and `\1` in an address, anchors |
| 7 | 2.3 | `/Alph/,/caverns/d` | two addresses select a range |
| 8 | 3.1 | `n`, `a\`, `d` | the paper's example; `d` ends the cycle but queued text still appears |
| 9 | 3.1 | `2,4c\` with `\   ` leading blanks | `c\` writes its text once for a range; keeping leading blanks |
| 10 | 3.2 | `s/to/by/w /dev/stdout` | substitution; the `w` flag writes only changed lines |
| 11 | 3.2 | `s/[.,;?:]/*P&*/gp` | `&`, the `g` flag, the `p` flag under `-n` |
| 12 | 3.2 | `/X/s/an/AN/p`, `gp`, `\4 \3 \2 \1` | first match vs all; replaced text is not rescanned; numbered groups |
| 13 | 3.3 | `/Khan/p`, `s`, `/KHAN/p`, `$w` | `p` writes the line as it is at that moment |
| 14 | 3.3 | `/Kubla/r data/note1` | `r` appends a file; a missing file is silently empty |
| 15 | 1.3, 3.4 | `$!N`, `s/\n/ + /` | two lines in the pattern space; `\n` is the imbedded newline |
| 16 | 3.4 | `$!N`, `/ran\nThrough/d`, `P`, `D` | the sliding two-line window; a pattern across a line break |
| 17 | 3.5 | `1h`, `1s/ did.*//`, `1x`, `G`, `s/\n/  :/` | the paper's hold-space example |
| 18 | 3.6 | `/an/!{ ... }` | `!` means don't; `{ }` groups commands |
| 19 | 3.6 | `/Kubla/b end`, `:again`, `s`, `t again` | labels, `b`, and `t` (branch only after a substitution) |
| 20 | 3.7 | `=`, `3q` | line numbers; `q` stops reading |

Left out: `w` to a real file (the steps use `/dev/stdout` so nothing is
written outside the session) and the ten-open-files limit, which modern
seds no longer have.

Verifying
---------

```bash
demo/verify.sh --dir tutorials/sed/1-mcmahon-paper/steps
```

plays all twenty steps headless and checks the editor, output and source
panes of each one. Note that `sedrepl`, unlike `awkrepl`, echoes the
script with its comments into the output pane, so the `#> not:` texts
are chosen never to occur in the narration.
