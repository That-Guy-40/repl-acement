# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day21 — BOSS 3: Ochre Orca — the job runner
DRILL_TITLE="runjobs.sh — a parallel job runner with atomic output, a summary, clean TERM, and manners"
DRILL_WEEK=3
DRILL_TOOLS=(timeout)

brief() {
    cat <<'EOF'
⚔ BOSS BATTLE 3 — functions, options, processes, traps and atomic files, together.

Write runjobs.sh:

    runjobs.sh [-j N] -o OUTDIR JOBSFILE

  • JOBSFILE has one shell command per line (blank lines and #-comments skipped).
  • Runs the jobs with at most N concurrently (default 2), in file order of START.
  • Job i's stdout+stderr go to OUTDIR/job-<i>.out — written ATOMICALLY (temp file in
    OUTDIR, renamed when the job finishes), so a reader never sees a partial file and
    no *.tmp is left behind.
  • When all jobs are done, writes OUTDIR/summary.tsv: `i<TAB>rc` per job, in job order.
  • Exit status = number of jobs with rc != 0.
  • --help prints usage on stdout and exits 0; a missing -o, a missing JOBSFILE, or
    -j 0 exit 64 with a message on stderr.
  • On SIGTERM: kills its still-running children (by PID — you have them), removes any
    temp files, and exits 143. No orphans: after the checker TERMs it, `pgrep -P <pid>`
    must find nothing.

The fixture: jobs.txt (6 quick jobs, one fails), slow.txt (3 jobs that sleep 5 s each).
The checker also times jobs.txt with -j 3 against -j 1: three-way parallelism must be
measurably faster than serial on six 0.5-second jobs — graded as a RATIO of the two times.

Why a boss: this is xargs -P / GNU parallel in forty lines, and every piece — the
PID table, the `wait` loop, the atomic rename, the TERM trap that reaches the
children — is a thing you have now done once on its own.
EOF
}

hint() {
    cat <<'EOF'
Launch each job as:  ( eval "$cmd" ) > "$out/.job-$i.tmp" 2>&1 && mv …   ← no: mv must run AFTER the job, in the same background unit:
    { ( eval "$cmd" ) > "$tmp" 2>&1; rc=$?; mv -f -- "$tmp" "$out/job-$i.out"; echo "$i	$rc" >> "$out/.rc"; } &
Track pids in an array; when ${#running[@]} == N, `wait -n` (bash 4.3+) then prune the finished pids with kill -0.
trap 'for p in "${pids[@]}"; do kill -TERM "$p" 2>/dev/null; done; rm -f "$out"/.job-*.tmp; exit 143' TERM
EOF
}

setup() {
    cat > jobs.txt <<'EOF'
# six quick jobs; the fourth fails
sleep 0.5; echo one
sleep 0.5; echo two
sleep 0.5; echo three >&2

sleep 0.5; echo four; exit 2
sleep 0.5; echo five
sleep 0.5; echo six
EOF
    cat > slow.txt <<'EOF'
sleep 5; echo slow-a
sleep 5; echo slow-b
sleep 5; echo slow-c
EOF
}

_ms() { date +%s%3N; }
check() {
    expect_executable runjobs.sh
    [[ -x runjobs.sh ]] || return
    local rc out t0 t1 serial par pid i kids
    rm -rf out; ( ./runjobs.sh -j 3 -o out jobs.txt ) >/dev/null 2>&1; rc=$?
    expect_eq "runjobs.sh -j 3 exit status (one failing job)" "$rc" 1
    for i in 1 2 3 4 5 6; do expect_file "out/job-$i.out"; done
    expect_content out/job-1.out $'one\n' "out/job-1.out"
    expect_content out/job-3.out $'three\n' "out/job-3.out (stderr captured too)"
    expect_content out/job-4.out $'four\n' "out/job-4.out"
    expect_lines out/summary.tsv "$(printf '%s\t%s\n' 1 0 2 0 3 0 4 2 5 0 6 0)" "out/summary.tsv"
    expect_eq "temp files left in out/" "$(find out -name '*.tmp' | wc -l)" 0
    # parallel speedup: 6 x 0.5 s → serial >= 3 s, -j 3 should be about 1 s (two rounds of three)
    rm -rf out; t0=$(_ms); ( ./runjobs.sh -j 1 -o out jobs.txt ) >/dev/null 2>&1; t1=$(_ms); serial=$((t1 - t0))
    rm -rf out; t0=$(_ms); ( ./runjobs.sh -j 3 -o out jobs.txt ) >/dev/null 2>&1; t1=$(_ms); par=$((t1 - t0))
    if (( serial >= 2800 )); then ok "-j 1 is serial (${serial} ms for 6 x 0.5 s)"; else bad "-j 1 took only ${serial} ms — it is not honouring the concurrency limit"; fi
    # a ratio, not a wall-clock window: on a loaded host both runs stretch, but six 0.5 s
    # jobs in two rounds of three must still finish in under 70% of the serial time
    if (( par >= 900 && par * 10 < serial * 7 )); then ok "-j 3 is parallel (${par} ms vs ${serial} ms serial)"; else bad "-j 3 took ${par} ms against ${serial} ms serial — expected roughly a third (two rounds of three)"; fi
    # manners
    out="$(./runjobs.sh --help 2>/dev/null)"; ./runjobs.sh --help >/dev/null 2>&1; rc=$?
    [[ -n "$out" && $rc -eq 0 ]] && ok "--help on stdout, exit 0" || bad "--help should print usage to stdout and exit 0 (rc=$rc)"
    ./runjobs.sh jobs.txt >/dev/null 2>&1; rc=$?;          expect_eq "missing -o exits 64" "$rc" 64
    ./runjobs.sh -o out nope.txt >/dev/null 2>&1; rc=$?;   expect_eq "missing JOBSFILE exits 64" "$rc" 64
    ./runjobs.sh -j 0 -o out jobs.txt >/dev/null 2>&1; rc=$?; expect_eq "-j 0 exits 64" "$rc" 64
    # SIGTERM: children die with it
    rm -rf out-slow
    ./runjobs.sh -j 3 -o out-slow slow.txt >/dev/null 2>&1 &
    pid=$!
    sleep 0.8
    kids="$(pgrep -P "$pid" | wc -l)"
    (( kids >= 1 )) && ok "runner has $kids child(ren) running before TERM" || bad "runner had no children 0.8 s in — did it start the jobs?"
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null; rc=$?
    expect_eq "exit status after SIGTERM" "$rc" 143
    sleep 0.3
    kids="$(pgrep -P "$pid" 2>/dev/null | wc -l)"
    # the parent is gone, so its children (if any survived) are now reparented; look for the sleeps by their parentage chain instead
    local orphans; orphans="$(pgrep -f "sleep 5; echo slow-" | wc -l)"
    (( orphans == 0 )) && ok "no job survived the TERM (no orphaned 'sleep 5' jobs)" || { bad "$orphans job(s) outlived the runner — the TERM trap must kill the children by PID"; pkill -TERM -f "sleep 5; echo slow-" 2>/dev/null; }
    expect_eq "temp files left in out-slow/ after TERM" "$(find out-slow -name '*.tmp' 2>/dev/null | wc -l)" 0
}

solve() {
    cat > runjobs.sh <<'EOF'
#!/usr/bin/env bash
# runjobs.sh [-j N] -o OUTDIR JOBSFILE — run shell commands N at a time, capture each atomically
set -uo pipefail
usage() { printf 'usage: runjobs.sh [-j N] -o OUTDIR JOBSFILE\n  -j N   run at most N jobs at once (default 2)\n  -o DIR write job-<i>.out and summary.tsv into DIR\n'; }
[[ ${1-} == --help ]] && { usage; exit 0; }
jobs_max=2 out=
while getopts ':j:o:h' opt; do
    case $opt in
        j) jobs_max=$OPTARG ;; o) out=$OPTARG ;; h) usage; exit 0 ;;
        :)  printf 'runjobs.sh: -%s needs an argument\n' "$OPTARG" >&2; exit 64 ;;
        \?) printf 'runjobs.sh: unknown option -%s\n' "$OPTARG" >&2; exit 64 ;;
    esac
done
shift $((OPTIND - 1))
jobsfile=${1-}
[[ -n $out ]]                      || { printf 'runjobs.sh: -o OUTDIR is required\n' >&2; exit 64; }
[[ -n $jobsfile && -r $jobsfile ]] || { printf 'runjobs.sh: JOBSFILE missing or unreadable\n' >&2; exit 64; }
[[ $jobs_max =~ ^[1-9][0-9]*$ ]]   || { printf 'runjobs.sh: -j needs a positive integer\n' >&2; exit 64; }
mkdir -p -- "$out"
rcfile="$out/.rc.$$"; : > "$rcfile"
declare -A pids=()                 # pid → job index
on_term() {
    local p
    for p in "${!pids[@]}"; do kill -TERM -- "$p" 2>/dev/null; done
    wait 2>/dev/null
    rm -f -- "$out"/.job-*.tmp "$rcfile"
    exit 143
}
trap on_term TERM
launch() {                         # launch I CMD — one background unit: run, then rename, then record
    local i=$1 cmd=$2 tmp="$out/.job-$i.tmp"
    { ( eval "$cmd" ) > "$tmp" 2>&1; local rc=$?
      mv -f -- "$tmp" "$out/job-$i.out"
      printf '%s\t%s\n' "$i" "$rc" >> "$rcfile"; } &
    pids[$!]=$i
}
reap() {                           # drop finished pids from the table
    local p
    for p in "${!pids[@]}"; do kill -0 -- "$p" 2>/dev/null || unset "pids[$p]"; done
}
i=0
while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    i=$((i + 1))
    while (( ${#pids[@]} >= jobs_max )); do wait -n 2>/dev/null; reap; done
    launch "$i" "$line"
done < "$jobsfile"
wait
LC_ALL=C sort -n -- "$rcfile" > "$out/summary.tsv"
rm -f -- "$rcfile"
awk -F'\t' '$2 != 0 { n++ } END { exit n + 0 }' "$out/summary.tsv"
EOF
    chmod +x runjobs.sh
}
