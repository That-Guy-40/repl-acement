# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day30 — Dotfiles and graduation
DRILL_TITLE="Dotfiles — an idempotent PATH, functions over aliases, and what you are taking home"
DRILL_WEEK=5
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
The last day builds the thing you keep: a bashrc.d/ directory of small, sourceable
files, each doing one job, each safe to source twice.

1. bashrc.d/10-path.sh — prepends $HOME/bin to PATH only if it is not already there.
   Sourcing it twice must leave exactly ONE $HOME/bin in PATH.
2. bashrc.d/20-functions.sh — three functions (not aliases — aliases cannot take
   arguments in the middle):
     mkcd DIR      mkdir -p DIR and cd into it
     up [N]        cd up N directories (default 1)
     extract FILE  dispatch on extension: .tar.gz/.tgz → tar xzf, .tar → tar xf,
                   .zip → unzip, .gz → gunzip; anything else → message on stderr,
                   return 1
3. bashrc.d/30-history.sh — your day-1 history settings (copy them forward).
4. bashrc.d/README.md — the one-line loader you would put in ~/.bashrc, in a code
   block:  for f in ~/.bashrc.d/*.sh; do . "$f"; done
5. graduation.txt — at least five lines, each naming one command, flag or idiom from
   the last 29 days that you did not have before. No format; this one is for you.

Every file must pass `bash -n`. The checker sources the directory into a clean bash
(with HOME pointed at the fixture) and exercises each function.

Why: fluency is not what you can look up, it is what your hands do without asking.
These files are how the last month becomes a habit instead of a memory.
EOF
}

hint() {
    cat <<'EOF'
case ":$PATH:" in *":$HOME/bin:"*) ;; *) PATH="$HOME/bin:$PATH" ;; esac
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }
up() { local n=${1:-1} p=; while (( n-- > 0 )); do p+=../; done; cd "${p:-.}" || return; }
EOF
}

setup() { mkdir -p bashrc.d; mkfile notes.txt "day 30 — see: workout day 30"; }

_src() {   # _src <snippet> — clean bash, HOME=fixture, bashrc.d sourced, then the snippet
    HOME="$PWD" bash --norc --noprofile -c 'for f in "$HOME"/bashrc.d/*.sh; do . "$f" || exit 99; done; '"$1" 2>&1
}
check() {
    local f out
    for f in 10-path.sh 20-functions.sh 30-history.sh; do
        expect_file "bashrc.d/$f"
        [[ -f bashrc.d/$f ]] && { bash -n "bashrc.d/$f" 2>/dev/null && ok "bashrc.d/$f parses" || bad "bashrc.d/$f has a syntax error (bash -n)"; }
    done
    expect_file bashrc.d/README.md
    [[ -f bashrc.d/README.md ]] && expect_grep bashrc.d/README.md 'for f in .*bashrc\.d/\*\.sh; do .*(\.|source) "?\$f"?; done' "README.md has the loader loop"
    [[ -f bashrc.d/10-path.sh && -f bashrc.d/20-functions.sh ]] || return
    out="$(_src 'IFS=: read -ra p <<<"$PATH"; n=0; for x in "${p[@]}"; do [[ $x == "$HOME/bin" ]] && n=$((n+1)); done; echo "count=$n first=${p[0]}"')"
    expect_eq "after sourcing once: HOME/bin is first and appears once" "$out" "count=1 first=$PWD/bin"
    out="$(_src '. "$HOME"/bashrc.d/10-path.sh; IFS=: read -ra p <<<"$PATH"; n=0; for x in "${p[@]}"; do [[ $x == "$HOME/bin" ]] && n=$((n+1)); done; echo "count=$n"')"
    expect_eq "after sourcing twice: still once (idempotent)" "$out" "count=1"
    rm -rf .scratch; mkdir -p .scratch/a/b/c
    out="$(_src 'cd .scratch && mkcd newdir/deeper && pwd')"; expect_eq "mkcd creates and enters" "$out" "$PWD/.scratch/newdir/deeper"
    out="$(_src 'cd .scratch/a/b/c && up 2 && pwd')";          expect_eq "up 2" "$out" "$PWD/.scratch/a"
    out="$(_src 'cd .scratch/a/b/c && up && pwd')";            expect_eq "up (default 1)" "$out" "$PWD/.scratch/a/b"
    out="$(_src 'type -t mkcd; type -t up; type -t extract' | tr '\n' ' ')"; expect_eq "mkcd/up/extract are functions" "$out" "function function function "
    printf 'payload\n' > .scratch/p.txt; ( cd .scratch && tar czf p.tgz p.txt && rm p.txt )
    out="$(_src 'cd .scratch && extract p.tgz && cat p.txt')"; expect_eq "extract p.tgz" "$out" "payload"
    out="$(_src 'extract .scratch/unknown.xyz; echo "rc=$?"' | tail -1)"; expect_eq "extract on an unknown extension returns 1" "$out" "rc=1"
    out="$(_src 'echo "$HISTCONTROL|$(shopt -q histappend && echo on)"')"; expect_match "30-history.sh sets HISTCONTROL and histappend" "$out" '(ignoredups|ignoreboth|erasedups).*\|on'
    rm -rf .scratch
    if [[ -f graduation.txt ]]; then
        expect_eq "graduation.txt has at least five non-empty lines" "$(( $(grep -c '[^[:space:]]' graduation.txt) >= 5 ))" 1
    else bad "graduation.txt is missing — write down what you are taking home"; fi
}

solve() {
    mkdir -p bashrc.d
    cat > bashrc.d/10-path.sh <<'EOF'
# prepend ~/bin to PATH exactly once
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) PATH="$HOME/bin:$PATH" ;;
esac
export PATH
EOF
    cat > bashrc.d/20-functions.sh <<'EOF'
# functions, because aliases cannot take arguments in the middle
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }
up() {
    local n=${1:-1} p=
    while (( n-- > 0 )); do p+=../; done
    cd -- "${p:-.}" || return
}
extract() {
    local f=$1
    case $f in
        # NOT `tar xzf -- "$f"`: in tar's old-style (dash-less) option syntax the word after
        # the option cluster is f's argument, so `--` would be taken as the archive name.
        *.tar.gz|*.tgz) tar -xzf "$f" ;;
        *.tar)          tar -xf "$f" ;;
        *.zip)          unzip -q -- "$f" ;;
        *.gz)           gunzip -- "$f" ;;
        *) printf 'extract: do not know how to extract %s\n' "$f" >&2; return 1 ;;
    esac
}
EOF
    cat > bashrc.d/30-history.sh <<'EOF'
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
shopt -s histappend
EOF
    cat > bashrc.d/README.md <<'EOF'
# bashrc.d

One file per concern, sourced in name order. Loader for `~/.bashrc`:

```bash
for f in ~/.bashrc.d/*.sh; do . "$f"; done
```
EOF
    printf '%s\n' 'Alt-. — last argument of the previous command' 'shopt -s extglob — !(keep).tmp' \
        '${f##*/} and ${f%.*} instead of basename' 'set -o pipefail — the pipeline fails when grep does' \
        'rsync --link-dest — snapshots that share unchanged files' 'flock -n — never let the 02:30 job overlap itself' > graduation.txt
}
