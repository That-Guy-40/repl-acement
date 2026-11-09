# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day18 — Processes, jobs and signals
DRILL_TITLE="Processes, jobs and signals — &, wait, \$!, kill by PID, trap TERM, timeout"
DRILL_WEEK=3
DRILL_TOOLS=(timeout)

brief() {
    cat <<'EOF'
worker.sh (provided) takes a number i, sleeps 0.1*i seconds and exits with i modulo 3.

1. supervise.sh N — starts workers 1..N in the BACKGROUND (all at once), remembers each
   one's PID ($!), waits for each one INDIVIDUALLY (wait PID) and prints, in worker
   order:  `worker i pid P rc R`. Its own exit status is the number of workers that
   failed (rc != 0). For N=4: workers 1,2,4 fail (1,2,1), worker 3 exits 0 → status 3.

2. graceful.sh — writes its PID to run/pidfile, then waits "forever" (a sleep loop),
   but on SIGTERM prints `shutting down`, removes run/pidfile, and exits 143 (128+15).
   The checker starts it, waits for the pidfile, sends TERM to THAT PID (never to a
   name — `pkill -f graceful` would also match the checker's own grep), and asserts
   the message, the exit status and that the pidfile is gone.
   Beware: `sleep 1000` in the foreground makes the trap wait until sleep ends —
   background the sleep and `wait` on it, or loop over short sleeps.

3. answers.txt — two lines:
     Q1  the exit status of  `timeout 1 sleep 5`
     Q2  the signal number SIGTERM is (the N in 128+N)

Why: `$!` + `wait` is how bash does concurrency without a framework; a TERM handler is
the difference between a clean stop and a half-written state file; and killing by PID
rather than by pattern is a rule this repository learned the expensive way.
EOF
}

hint() {
    cat <<'EOF'
for i in $(seq 1 "$n"); do ./worker.sh "$i" & pids[i]=$!; done
for i in $(seq 1 "$n"); do wait "${pids[i]}"; rc=$?; …; done
trap 'echo "shutting down"; rm -f run/pidfile; exit 143' TERM
echo $$ > run/pidfile; while :; do sleep 0.2 & wait $!; done
EOF
}

setup() {
    mkdir -p run
    cat > worker.sh <<'EOF'
#!/usr/bin/env bash
# worker.sh I — sleep 0.1*I seconds, exit I mod 3
i=${1:?}
sleep "$(awk -v i="$i" 'BEGIN { printf "%.1f", i/10 }')"
exit $(( i % 3 ))
EOF
    chmod +x worker.sh
    mkfile notes.txt "Q1  exit status of: timeout 1 sleep 5" "Q2  signal number of SIGTERM"
}

check() {
    local out rc pid i
    expect_executable supervise.sh
    if [[ -x supervise.sh ]]; then
        out="$(./supervise.sh 4 2>/dev/null)"; rc=$?
        expect_eq "supervise.sh 4 exit status (3 failures)" "$rc" 3
        expect_eq "supervise.sh 4 output shape" "$(sed -E 's/pid [0-9]+/pid P/' <<<"$out")" $'worker 1 pid P rc 1\nworker 2 pid P rc 2\nworker 3 pid P rc 0\nworker 4 pid P rc 1'
        # the pids must be distinct real numbers — four workers, four processes
        expect_eq "supervise.sh reported 4 distinct pids" "$(grep -oE 'pid [0-9]+' <<<"$out" | sort -u | wc -l)" 4
    fi
    expect_executable graceful.sh
    if [[ -x graceful.sh ]]; then
        rm -f run/pidfile
        ./graceful.sh > run/graceful.out 2>&1 &
        local bg=$!
        for i in $(seq 1 50); do [[ -s run/pidfile ]] && break; sleep 0.1; done
        if [[ -s run/pidfile ]]; then
            pid="$(cat run/pidfile)"
            ok "graceful.sh wrote its pid ($pid) to run/pidfile"
            kill -TERM "$pid" 2>/dev/null          # by PID — the only safe way
            wait "$bg" 2>/dev/null; rc=$?
            expect_eq "graceful.sh exit status after SIGTERM" "$rc" 143
            grep -q 'shutting down' run/graceful.out && ok "graceful.sh printed 'shutting down'" || bad "graceful.sh did not print 'shutting down' on TERM"
            [[ ! -e run/pidfile ]] && ok "run/pidfile removed on the way out" || bad "run/pidfile still exists after TERM"
        else
            bad "graceful.sh never wrote run/pidfile within 5 s"
            kill "$bg" 2>/dev/null; wait "$bg" 2>/dev/null
        fi
    fi
    if [[ -f answers.txt ]]; then
        expect_eq "Q1: timeout's exit status when the command is killed" "$(sed -n 1p answers.txt | tr -d '[:space:]')" 124
        expect_eq "Q2: SIGTERM's number" "$(sed -n 2p answers.txt | tr -d '[:space:]')" 15
    else bad "answers.txt is missing"; fi
}

solve() {
    cat > supervise.sh <<'EOF'
#!/usr/bin/env bash
# supervise.sh N — run N workers concurrently, report each, exit = number failed
set -u
n=${1:?usage: supervise.sh N}
declare -a pids
for (( i = 1; i <= n; i++ )); do
    ./worker.sh "$i" &
    pids[i]=$!
done
failed=0
for (( i = 1; i <= n; i++ )); do
    wait "${pids[i]}"; rc=$?
    printf 'worker %d pid %d rc %d\n' "$i" "${pids[i]}" "$rc"
    (( rc != 0 )) && failed=$((failed + 1))
done
exit "$failed"
EOF
    cat > graceful.sh <<'EOF'
#!/usr/bin/env bash
# graceful.sh — run until SIGTERM, then clean up and exit 143
set -u
mkdir -p run
trap 'echo "shutting down"; rm -f run/pidfile; exit 143' TERM
echo $$ > run/pidfile
# A foreground `sleep` would delay the trap until it finished; background it and wait,
# because `wait` IS interruptible by a trapped signal.
while :; do sleep 0.2 & wait $!; done
EOF
    chmod +x supervise.sh graceful.sh
    printf '%s\n' 124 15 > answers.txt
}
