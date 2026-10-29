Learning sed with sedrepl
=========================

Three step-by-step tutorials that run inside `sedrepl`. Each step is typed
into the editor pane for you, with the explanation written as comments above
the script; the output pane shows the command line, the script, and the
result; the right-hand pane shows the script highlighted. Between steps the
editor is yours: change the script, save, and watch the output change.
Press F5 for the next step, `C-b d` to leave.

| Tutorial | Based on | Run |
|----------|----------|-----|
| [1. McMahon's paper](1-mcmahon-paper/) | Lee E. McMahon, *SED -- A Non-interactive Text Editor* (1978; vendored in [`refs/`](refs/)) | `tutorials/sed/1-mcmahon-paper/run.sh` |
| [2. Pement's one-liners](2-pement-one-liners/) | Eric Pement, *Useful one-line scripts for sed* (vendored in [`refs/`](refs/)) | `tutorials/sed/2-pement-one-liners/run.sh` |
| [3. Krumins' cheat sheet](3-krumins-cheat-sheet/) | Peteris Krumins, *Sed Cheat Sheet* (vendored in [`refs/`](refs/)) | `tutorials/sed/3-krumins-cheat-sheet/run.sh` |

Start with 1 to learn the editor from the person who wrote it, in order
and on five lines of Coleridge; 2 when you want things you can paste into
a shell today; 3 when you want to know what every command does to the
pattern space and the hold buffer, and what GNU sed added.

Every tutorial is verified the same way as the fraud demo: `demo/verify.sh
--dir tutorials/sed/<tutorial>/steps` plays it headless and checks all
three panes of every step. Options such as `--steps 3,7` (only those steps)
and `DEMO_TYPE_DELAY=0` (no typing animation) work on `run.sh` too; see
[`demo/README.md`](../../demo/README.md) for the step-file format if you
want to add steps of your own.

Needs `tmux`, `entr`, `vim` and GNU `sed` (the steps were written against
4.9; a few use GNU extensions such as `\n` in a replacement, `first~step`
addresses or `-E`, and say so). The tutorials run with a throwaway `HOME`,
so your own `~/.repl.sed` is never touched.
