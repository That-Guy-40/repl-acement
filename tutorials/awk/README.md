Learning AWK with awkrepl
=========================

Three step-by-step tutorials that run inside `awkrepl`. Each step is typed
into the editor pane for you, with the explanation written as comments above
the program; the output pane shows the result, the right-hand pane shows
how gawk itself parsed the program. Between steps the editor is yours:
change the program, save, and watch the output change. Press F5 for the
next step, `C-b d` to leave.

| Tutorial | Based on | Run |
|----------|----------|-----|
| [1. Pement's one-liners](1-pement-one-liners/) | Eric Pement, *Handy one-liners for awk* (vendored in [`refs/`](refs/)) | `tutorials/awk/1-pement-one-liners/run.sh` |
| [2. The Grymoire tutorial](2-grymoire-tutorial/) | Bruce Barnett, *Awk* at grymoire.com (linked, not vendored: the page forbids copies) | `tutorials/awk/2-grymoire-tutorial/run.sh` |
| [3. Krumins' cheat sheet](3-krumins-cheat-sheet/) | Peteris Krumins, *AWK Cheat Sheet* (vendored in [`refs/`](refs/)) | `tutorials/awk/3-krumins-cheat-sheet/run.sh` |

Start with 1 if you want results fast, 2 if you want the language explained
in order, 3 when you want to know what else is in the box.

Every tutorial is verified the same way as the fraud demo: `demo/verify.sh
--dir tutorials/awk/<tutorial>/steps` plays it headless and checks all
three panes of every step. Options such as `--steps 3,7` (only those steps)
and `DEMO_TYPE_DELAY=0` (no typing animation) work on `run.sh` too; see
[`demo/README.md`](../../demo/README.md) for the step-file format if you
want to add steps of your own.

Needs `tmux`, `entr`, `vim` and `gawk`. The tutorials run with a throwaway
`HOME`, so your own `~/.repl.awk` is never touched.
