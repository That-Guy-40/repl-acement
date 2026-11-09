# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day19 — /proc and process introspection
DRILL_TITLE="/proc — a process reads its own status, fds, cmdline and cwd from the kernel"
DRILL_WEEK=3
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
Write introspect.sh, which prints five facts about ITSELF, read from /proc/self (not from
$$ / $PPID / ps — the checker only grades truth, but the point is to read the kernel's
view directly):

    pid=<its pid>                      /proc/self/status  (the Pid: line) or /proc/self/stat
    ppid=<its parent's pid>            /proc/self/status  (PPid:)
    fds=<number of open file descriptors>   count the entries of /proc/self/fd — from INSIDE
                                       the script, with a builtin (a glob), because `ls
                                       /proc/self/fd` would count ls's fds, not yours
    cmdline=<argv joined by single spaces>  /proc/self/cmdline is NUL-separated; read it
                                       with a BUILTIN (mapfile -d ''), because `tr <
                                       /proc/self/cmdline` opens the file in tr's process
    cwd=<absolute working directory>   readlink /proc/self/cwd

The checker runs  ( exec bash introspect.sh alpha beta )  and compares pid with the
subshell's own $BASHPID, ppid with the checker's pid, cmdline with `bash <path> alpha
beta`, cwd with the fixture, and runs it twice — once with two extra fds open
(3</dev/null 4</dev/null) — expecting fds to be exactly 2 larger the second time.

Also: answers.txt, two lines —
    Q1  what does /proc/<pid>/exe point to?   (one of: the executable, the binary, …)
    Q2  which /proc file holds the 1/5/15-minute load averages?

Why: everything ps, top, lsof and pgrep know, they learned by reading /proc. Reading it
yourself is faster than remembering their flags, and it is the only way to know what
is true about THIS process rather than the one a tool spawns to look.
EOF
}

hint() {
    cat <<'EOF'
pid=$(awk '/^Pid:/ {print $2}' /proc/self/status)      # careful: $(…) forks a subshell whose /proc/self is the SUBSHELL
                                                        # → read with the builtin instead:  while read -r k v; do …; done < /proc/self/status
fds=(/proc/self/fd/*); echo "fds=${#fds[@]}"           # a glob inside the script counts the script's own fds
mapfile -d '' argv < /proc/self/cmdline; echo "cmdline=${argv[*]}"   # a builtin: the open happens in YOUR process
# (`tr '\0' ' ' < /proc/self/cmdline` prints "tr \0": the forked child opens the file, and it is tr)
EOF
}

setup() { mkfile notes.txt "Q1  /proc/<pid>/exe is a symlink to … ?" "Q2  which /proc file has the load averages?"; }

check() {
    expect_executable introspect.sh
    if [[ -x introspect.sh ]]; then
        local out out2 me mypid fds1 fds2
        me=$BASHPID          # not $$: check() runs in a subshell, and the script's parent is THAT shell
        out="$( printf 'me=%s\n' "$BASHPID"; exec bash "$PWD/introspect.sh" alpha beta )"
        mypid="$(sed -n 's/^me=//p' <<<"$out")"
        expect_eq "pid= equals the process that exec'd the script" "$(sed -n 's/^pid=//p' <<<"$out")" "$mypid"
        expect_eq "ppid= equals the checker's pid" "$(sed -n 's/^ppid=//p' <<<"$out")" "$me"
        expect_eq "cmdline=" "$(sed -n 's/^cmdline=//p' <<<"$out" | sed 's/ *$//')" "bash $PWD/introspect.sh alpha beta"
        expect_eq "cwd=" "$(sed -n 's/^cwd=//p' <<<"$out")" "$PWD"
        fds1="$(sed -n 's/^fds=//p' <<<"$out")"
        out2="$( exec bash "$PWD/introspect.sh" 3</dev/null 4</dev/null )"
        fds2="$(sed -n 's/^fds=//p' <<<"$out2")"
        if [[ "$fds1" =~ ^[0-9]+$ && "$fds2" =~ ^[0-9]+$ ]]; then
            expect_eq "fds= grows by exactly 2 when two extra fds are inherited ($fds1 → $fds2)" "$((fds2 - fds1))" 2
        else bad "fds= is not a number (got '$fds1' and '$fds2')"; fi
    fi
    if [[ -f answers.txt ]]; then
        expect_match "Q1 (/proc/<pid>/exe)" "$(sed -n 1p answers.txt | tr 'A-Z' 'a-z')" '(executable|binary|program|elf|running)'
        expect_match "Q2 (load averages)" "$(sed -n 2p answers.txt | tr 'A-Z' 'a-z')" 'loadavg'
    else bad "answers.txt is missing"; fi
}

solve() {
    cat > introspect.sh <<'EOF'
#!/usr/bin/env bash
# introspect.sh — five facts about THIS process, straight from /proc/self.
# No $(...) around the /proc/self reads: a command substitution is a forked subshell,
# whose /proc/self is the subshell. Redirections are opened by this shell, so they see us.
set -u
while read -r key val _; do
    case $key in Pid:) pid=$val ;; PPid:) ppid=$val ;; esac
done < /proc/self/status
fds=(/proc/self/fd/*)                      # the glob runs in this process
printf 'pid=%s\n' "$pid"
printf 'ppid=%s\n' "$ppid"
printf 'fds=%s\n' "${#fds[@]}"
mapfile -d '' argv < /proc/self/cmdline   # builtin: opened by THIS process. `tr < /proc/self/cmdline` would read tr's.
printf 'cmdline=%s\n' "${argv[*]}"
printf 'cwd=%s\n' "$(readlink /proc/self/cwd)"   # cwd is inherited by the subshell, so this one is safe
EOF
    chmod +x introspect.sh
    printf '%s\n' 'the executable (binary) the process is running' '/proc/loadavg' > answers.txt
}
