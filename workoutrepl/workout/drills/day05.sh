# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day05 — Parameter expansion, no forks
DRILL_TITLE="Parameter expansion — basename, dirname, sed and tr without a single fork"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
paths.txt lists one path per line. Write two scripts that use ONLY bash — no basename,
dirname, sed, tr, cut, awk — the checker runs them with an EMPTY PATH, so any external
command fails with "command not found".

1. pe.sh — reads paths.txt from the current directory and prints, per line:
       dir=<dir> base=<base> stem=<stem> ext=<ext>
   where  dir  = everything before the last `/`, or `.` if there is no slash
          base = everything after the last `/`
          stem = base without its LAST `.ext` (whole base if it has no dot)
          ext  = the text after the last dot of base ('' if none)
   e.g.  /var/log/syslog.1    → dir=/var/log base=syslog.1 stem=syslog ext=1
         archive.tar.gz       → dir=. base=archive.tar.gz stem=archive.tar ext=gz
         Makefile             → dir=. base=Makefile stem=Makefile ext=

2. defaults.sh — prints exactly these six lines, driven by the environment:
       name=<$NAME, or `anon` when NAME is unset or empty>
       shout=<$NAME upper-cased, or ANON>
       len=<length of the shout value>
       slug=<$TITLE with every space replaced by `-` and lower-cased>
       mid=<characters 2..4 (zero-based offset 2, length 3) of $TITLE>
       set=<`yes` if VERBOSE is set to anything, `no` otherwise>
   The checker runs it twice: with NAME=Ada TITLE='Hello World Again' VERBOSE=1, and
   with NAME and VERBOSE unset and TITLE='x y'.

Why: every `$(basename "$f")` is a fork+exec. In a loop over ten thousand files that is
the difference between 50 ms and 20 s — and the builtin forms are also the ones that
cannot be broken by a filename that looks like an option.
EOF
}

hint() {
    cat <<'EOF'
${p%/*}   ${p##*/}   ${b%.*}   ${b##*.}   — and `[[ $p == */* ]]`, `[[ $b == *.* ]]` to
decide whether the delimiter exists at all (if it does not, `${p%/*}` returns p unchanged).
${v:-default}  ${v^^}  ${#v}  ${v// /-}  ${v,,}  ${v:2:3}  ${v:+yes}
EOF
}

setup() {
    printf '%s\n' /var/log/syslog.1 archive.tar.gz Makefile ./notes.md /etc/ssh/sshd_config \
        'photos/My Photo.JPG' /usr/local/bin/ 'a.b.c.d' > paths.txt
}

PE_WANT='dir=/var/log base=syslog.1 stem=syslog ext=1
dir=. base=archive.tar.gz stem=archive.tar ext=gz
dir=. base=Makefile stem=Makefile ext=
dir=. base=notes.md stem=notes ext=md
dir=/etc/ssh base=sshd_config stem=sshd_config ext=
dir=photos base=My Photo.JPG stem=My Photo ext=JPG
dir=/usr/local/bin base= stem= ext=
dir=. base=a.b.c.d stem=a.b.c ext=d'

check() {
    local got
    expect_file pe.sh
    if [[ -f pe.sh ]]; then
        # `env -i PATH=` empties the environment AND the search path, so bash itself has to be
        # named by absolute path — the script's own `#!/usr/bin/env bash` would not resolve.
        local BASHBIN; BASHBIN="$(command -v bash)"
        got="$(env -i PATH= "$BASHBIN" ./pe.sh 2>&1)"; rc=$?
        if (( rc == 0 )); then ok "pe.sh runs with an EMPTY PATH (no externals)"; else bad "pe.sh fails with an empty PATH (rc=$rc) — something forks: ${got##*$'\n'}"; fi
        expect_eq "pe.sh output" "$got" "$PE_WANT"
    fi
    expect_file defaults.sh
    if [[ -f defaults.sh ]]; then
        local BASHBIN; BASHBIN="$(command -v bash)"
        got="$(env -i PATH= NAME=Ada TITLE='Hello World Again' VERBOSE=1 "$BASHBIN" ./defaults.sh 2>&1)"
        expect_eq "defaults.sh (NAME=Ada, VERBOSE set)" "$got" $'name=Ada\nshout=ADA\nlen=3\nslug=hello-world-again\nmid=llo\nset=yes'
        got="$(env -i PATH= TITLE='x y' "$BASHBIN" ./defaults.sh 2>&1)"
        expect_eq "defaults.sh (NAME unset, VERBOSE unset)" "$got" $'name=anon\nshout=ANON\nlen=4\nslug=x-y\nmid=y\nset=no'
    fi
}

solve() {
    cat > pe.sh <<'EOF'
#!/usr/bin/env bash
# dir/base/stem/ext with parameter expansion only
while IFS= read -r p; do
    if [[ $p == */* ]]; then dir=${p%/*}; else dir=.; fi
    base=${p##*/}
    if [[ $base == *.* ]]; then stem=${base%.*}; ext=${base##*.}; else stem=$base; ext=; fi
    printf 'dir=%s base=%s stem=%s ext=%s\n' "$dir" "$base" "$stem" "$ext"
done < paths.txt
EOF
    cat > defaults.sh <<'EOF'
#!/usr/bin/env bash
name=${NAME:-anon}
shout=${name^^}
printf 'name=%s\n'  "$name"
printf 'shout=%s\n' "$shout"
printf 'len=%s\n'   "${#shout}"
slug=${TITLE// /-}
printf 'slug=%s\n'  "${slug,,}"
printf 'mid=%s\n'   "${TITLE:2:3}"
isset=${VERBOSE+yes}            # `yes` if VERBOSE is set (even to ''), else empty
printf 'set=%s\n'   "${isset:-no}"
EOF
}
