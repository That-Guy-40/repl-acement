# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day04 — Redirection and file descriptors
DRILL_TITLE="Redirection and file descriptors — stdout, stderr, and the ones you open yourself"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
noisy.sh (provided) prints four lines on stdout and three on stderr, interleaved.
Write three small scripts that drive it — do not edit noisy.sh:

1. split.sh — runs ./noisy.sh so that stdout lands in out.log, stderr in err.log, AND
   a combined copy of both in all.log, in one invocation (think tee and >(…)).
   After `./split.sh`: out.log has exactly the 4 out lines, err.log exactly the 3 err
   lines, all.log all 7 (any order).

2. swap.sh — runs ./noisy.sh with stdout and stderr SWAPPED, so that
   `./swap.sh 2>/dev/null` prints only the err lines and `./swap.sh >/dev/null` only
   the out lines. The classic three-fd dance: 3>&1 1>&2 2>&3 3>&-.

3. fd3.sh — opens fd3.txt on file descriptor 3 with exec, writes the lines
   `one`, `two`, `three` to it via >&3 (not by naming the file three times), then
   closes fd 3 — and must still exit 0.

Why: `2>&1 >file` and `>file 2>&1` are different programs. Fluent people read a
redirection list left to right as a sequence of dup2() calls, and once you see fds as
numbered slots you can open your own, swap them, and tee them without temp files.
EOF
}

hint() {
    cat <<'EOF'
./noisy.sh > >(tee out.log >> all.log) 2> >(tee err.log >> all.log)   # then `wait`
./noisy.sh 3>&1 1>&2 2>&3 3>&-
exec 3>fd3.txt; printf 'one\n' >&3; …; exec 3>&-
EOF
}

setup() {
    cat > noisy.sh <<'EOF'
#!/usr/bin/env bash
# four lines to stdout, three to stderr, interleaved
echo "out 1"; echo "err 1" >&2
echo "out 2"; echo "err 2" >&2
echo "out 3"; echo "err 3" >&2
echo "out 4"
EOF
    chmod +x noisy.sh
}

OUT_LINES=$'out 1\nout 2\nout 3\nout 4'
ERR_LINES=$'err 1\nerr 2\nerr 3'

check() {
    local got
    expect_executable split.sh
    if [[ -x split.sh ]]; then
        rm -f out.log err.log all.log
        ( ./split.sh ) >/dev/null 2>&1; sleep 0.2
        expect_lines out.log "$OUT_LINES" "out.log (stdout only)"
        expect_lines err.log "$ERR_LINES" "err.log (stderr only)"
        if [[ -f all.log ]]; then
            got="$(sort all.log)"
            expect_eq "all.log (both streams, 7 lines, order free)" "$got" "$(printf '%s\n%s\n' "$ERR_LINES" "$OUT_LINES" | sort)"
        else bad "all.log is missing"; fi
    fi
    expect_executable swap.sh
    if [[ -x swap.sh ]]; then
        got="$(./swap.sh 2>/dev/null)";  expect_eq "swap.sh: stdout now carries the err lines" "$got" "$ERR_LINES"
        got="$(./swap.sh 2>&1 >/dev/null)"; expect_eq "swap.sh: stderr now carries the out lines" "$got" "$OUT_LINES"
    fi
    expect_executable fd3.sh
    if [[ -x fd3.sh ]]; then
        rm -f fd3.txt
        expect_rc "fd3.sh" 0 ./fd3.sh
        expect_lines fd3.txt $'one\ntwo\nthree' "fd3.txt (written through fd 3)"
    fi
}

solve() {
    cat > split.sh <<'EOF'
#!/usr/bin/env bash
# stdout → out.log, stderr → err.log, both → all.log — via two process substitutions
./noisy.sh > >(tee out.log >> all.log) 2> >(tee err.log >> all.log)
wait    # let both tee processes finish before we return
EOF
    cat > swap.sh <<'EOF'
#!/usr/bin/env bash
# 3>&1 saves stdout in fd 3; 1>&2 points stdout at stderr; 2>&3 points stderr at the
# saved stdout; 3>&- closes the scratch fd so the child does not inherit it.
./noisy.sh 3>&1 1>&2 2>&3 3>&-
EOF
    cat > fd3.sh <<'EOF'
#!/usr/bin/env bash
exec 3>fd3.txt            # open the file ONCE, on fd 3
printf '%s\n' one >&3
printf '%s\n' two >&3
printf '%s\n' three >&3
exec 3>&-                 # close it
EOF
    chmod +x split.sh swap.sh fd3.sh
}
