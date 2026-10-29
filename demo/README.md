Fraud triage with repl-acement: a self-running demo
=================================================

A 15-minute, hands-off demo for a fraud-detection lead (written for JR, who
has done years of data cleaning and analysis with `sed`, `awk` and `perl`).
It plays one Saturday of card transactions through all six REPLs in the
order JR already knows them, then the ones that are new: `awk`, `sed`,
`perl`, then Miller, `jq`, `yq`, and finally `awk` again on a real 284,807
row dataset.

The demo types each step into a real editor (vim) in the top pane and
saves. That save is what re-runs the tool in the bottom-left pane, exactly
as it would for a person. The narration is written into each step as `#`
comments, so the audience reads it in the editor while the result appears
below.

Running it
----------

```bash
demo/fetch-deps.sh    # once: Mike Farah's yq into demo/bin, the real dataset (~150 MB)
demo/play.sh          # in a terminal at least 180 columns by 50 rows
```

`play.sh` opens its own tmux session (socket `demo-<pid>`, so it never
touches your tmux server or your `~/.repl.*` files: the REPLs run with a
throwaway `HOME`). Sit back; it detaches you when it finishes. `C-b d` at
any time leaves early. Useful knobs:

| Option / variable | Effect |
|-------------------|--------|
| `--steps 1,4,9` | play only those steps |
| `DEMO_PAUSE_SCALE=0.5` | halve every narration pause (default pauses add up to about 9 min) |
| `DEMO_TYPE_DELAY=0` | no typing animation |
| `--fast --no-attach --capture DIR` | headless run, no pauses; what `verify.sh` uses |

Without `fetch-deps.sh`, step 11 (yq) and step 12 (the real dataset) are
skipped with a note in the driver log and the rest plays.

Verifying it
------------

```bash
demo/verify.sh            # all steps; exit 0 only if nothing failed
demo/verify.sh --steps 3,9 --keep
```

`verify.sh` runs the whole demo headless in a 200x50 tmux session, and for
every step captures the three panes after the output appears and checks:

- the editor pane shows the step's title line (the input went in),
- the output pane contains every `#> must:` text and none of the `#> not:`
  texts (including the `# command:` line, which proves `#ARGS` and
  perlrepl's automatic `-n` took effect),
- the source pane contains the `#> source:` text (the right-hand pane
  refreshed).

A step whose dependency is missing reports UNKNOWN, never PASS. Every step
must carry at least one `not:` row, and the string helpers are checked
against a known-bad capture before anything runs, so an all-green result
means the checks ran, not that they can't fail.

The story
---------

The data (`data/transactions.csv`, 62 rows, nine fields: id, timestamp,
card, amount, merchant, MCC, country, channel, device) is synthetic. Eight
ordinary cardholders go about a Saturday; planted among them are five
patterns a fraud team sees every week, plus two decoys that look suspicious
and aren't.

| Step | Tool | What it finds | The REPL feature on show |
|------|------|---------------|--------------------------|
| 1 | awkrepl | the eight transactions over $500, two of them legitimate (a flight, a TV) | `#ARGS -F,`; a bare pattern auto-prints |
| 2 | awkrepl | card testing: six $1 charges on one card at 2 AM, then $489 | `END` block, the single $0.99 decoy stays quiet |
| 3 | awkrepl | a duplicate post: same card, merchant, amount, 4 seconds apart | `seen[]` with a time window; the eight $100 gift-card buys do not trip it |
| 4 | sedrepl | PCI masking (first 6, last 4) plus the NG/RO rows | `#ARGS -n`, substitution and address in one script |
| 5 | sedrepl | only the small hours, channel code spelled out | `!d`, feeding the next tool |
| 6 | perlrepl | impossible travel: New York to Lagos in 36 minutes | perlrepl adds `-n` by itself; the US-to-GB-in-9-hours decoy passes |
| 7 | perlrepl | velocity: five transactions in a sliding ten-minute window, two cards | `#ARGS -a -F,` autosplit into `@F` |
| 8 | mlrrepl | structuring: three crypto buys at $2,999, $2,995, $2,998 | `$amount` by name, `--opprint` table |
| 9 | mlrrepl | the ring: one device, four different cards (a family tablet with two is left alone) | `filter false` plus an `end` block |
| 10 | jqrepl | the case object for the ring: cards, $12,422 exposure, 7 transactions | `#ARGS -R -s`, jq straight off CSV |
| 11 | yqrepl | the same case as a YAML ticket for the SOC queue | `#ARGS -p csv -o yaml` |
| 12 | awkrepl | the real public credit-card fraud set: 284,807 rows, 492 fraud, mean fraud amount $122 vs $88 | no `#DATA`; `-v file=` and `getline` |

Suggested framing for JR: steps 1 to 7 are things you have typed into a
terminal a hundred times, except that you never had to re-run anything,
scroll back, or lose the previous attempt. Steps 8 to 11 ask the same
questions with tools that name fields and emit structured output, in the
same window with the same file conventions. Step 12 is the reminder that
none of this is a toy.

Files
-----

| Path | What it is |
|------|------------|
| `play.sh` | the driver: opens the session, types each step, waits for the output |
| `verify.sh` | runs `play.sh` headless and asserts every pane of every step |
| `fetch-deps.sh` | downloads `bin/yq` (v4.54.1) and `data/real/creditcard.csv` (checksummed) |
| `steps/NN_*.repl` | one step each: `#>` directives, then the text typed into the editor; `@CSV@` is replaced by the data file, `@REAL@` by the real dataset's path |
| `data/transactions.csv` | the synthetic Saturday |
| `vimrc` | the minimal vim config the demo's editor uses |
| `bin/`, `data/real/` | fetched, not in git |

Writing another step
--------------------

Copy a step file, keep the header:

```
#> tool: mlrrepl              which REPL
#> wait: TEXT                 the driver waits for this in the output pane
#> pause: 45                  seconds of narration before the next step
#> must: TEXT                 verify: output pane must contain (repeatable)
#> not: TEXT                  verify: output pane must not contain (repeatable; at least one)
#> source: TEXT               verify: source pane must contain
#> needs: real | yq-mikefarah optional dependency; the step is skipped without it
```

Everything after the directives is typed as-is; the first line is the
title. Remember that every REPL except awkrepl echoes the program, comments
included, into the output pane above the result, so a `not:` text must not
appear in your own source either. The driver strips the trailing newline
of the pasted block so vim doesn't leave an empty last line; mlrrepl itself
also drops blank lines at either end of the data (Miller's CSV reader would
otherwise reject them with `header/data length mismatch`), and the mlr
steps assert that `mismatch` is absent as a regression check.

Requirements
------------

`bash`, `tmux` 3+, `entr`, `vim`, and the tools: `gawk`, `sed`, `perl`,
`mlr` 6, `jq`, plus Mike Farah's `yq` 4.x for step 11 (this machine's
system `yq` 4.2.0 is too old for yqrepl's version check; `fetch-deps.sh`
puts a current one in `demo/bin`, which `play.sh` prepends to `PATH`).
