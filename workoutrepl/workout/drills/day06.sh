# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day06 — Exit status, pipelines, pipefail, traps
DRILL_TITLE="Exit status — pipefail, PIPESTATUS, ERR and EXIT traps"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
Three small scripts about the one thing scripts most often get wrong: knowing that
they failed.

1. pipeline.sh (provided, broken) — `grep ERROR "$1" | sort | head -3`. Run it on a
   file that does not exist: it prints an error from grep and EXITS 0, because a
   pipeline's status is its LAST command's, and head is happy. Fix it so that
     • a missing file makes it exit NON-ZERO, and
     • it prints `ERROR: line N: <the failing command>` to stderr — from an ERR trap,
       using $LINENO and $BASH_COMMAND — while
     • on data.log (provided) it still prints the first 3 sorted ERROR lines and exits 0.

2. status.sh — runs the fixed pipeline  false | true | false  and prints the three
   individual statuses on one line:  1 0 1   (hint: PIPESTATUS, captured IMMEDIATELY).

3. cleanup.sh — creates a temp file under ./tmp/ with mktemp, registers an EXIT trap
   that removes it, then runs a command that fails with status 3 (e.g. `exit 3` or
   `(exit 3)` under set -e) — the checker asserts the script exits 3 AND ./tmp/ is empty
   afterwards. The trap must run on the failure path, not only on success.

Why: `set -e` without pipefail is a false sense of safety; PIPESTATUS vanishes after
the next command; and a cleanup that runs only when things go well is not a cleanup.
EOF
}

hint() {
    cat <<'EOF'
set -o pipefail                      # pipeline status = last NON-ZERO status
trap 'echo "ERROR: line $LINENO: $BASH_COMMAND" >&2' ERR
false | true | false; echo "${PIPESTATUS[@]}"
tmp=$(mktemp ./tmp/XXXXXX); trap 'rm -f "$tmp"' EXIT
EOF
}

setup() {
    mkdir -p tmp
    mkfile data.log "INFO start" "ERROR disk full on /dev/sdb" "WARN slow query" \
        "ERROR connection refused" "INFO retry" "ERROR auth failed for root" "ERROR disk full on /dev/sda" "INFO done"
    cat > pipeline.sh <<'EOF'
#!/usr/bin/env bash
# print the first three ERROR lines of $1, sorted
grep ERROR "$1" | sort | head -3
EOF
    chmod +x pipeline.sh
}

check() {
    local got rc err
    expect_executable pipeline.sh
    if [[ -x pipeline.sh ]]; then
        got="$(./pipeline.sh data.log 2>/dev/null)"; rc=$?
        expect_eq "pipeline.sh data.log → first 3 sorted ERROR lines" "$got" $'ERROR auth failed for root\nERROR connection refused\nERROR disk full on /dev/sda'
        expect_eq "pipeline.sh data.log exit status" "$rc" 0
        err="$(./pipeline.sh no-such-file.log 2>&1 >/dev/null)"; rc=$?
        if (( rc != 0 )); then ok "pipeline.sh on a missing file exits non-zero ($rc)"; else bad "pipeline.sh on a missing file exits 0 — the pipeline's status is head's, not grep's (set -o pipefail)"; fi
        if grep -qE '^ERROR: line [0-9]+: ' <<<"$err"; then ok "pipeline.sh reports 'ERROR: line N: <command>' from an ERR trap"
        else bad "pipeline.sh stderr lacks an 'ERROR: line N: <command>' line (trap … ERR with \$LINENO and \$BASH_COMMAND); got: $(head -1 <<<"$err")"; fi
    fi
    expect_executable status.sh
    if [[ -x status.sh ]]; then
        got="$(./status.sh 2>/dev/null | tr -s ' ' | sed 's/^ *//;s/ *$//')"
        expect_eq "status.sh prints the three pipeline statuses" "$got" "1 0 1"
    fi
    expect_executable cleanup.sh
    if [[ -x cleanup.sh ]]; then
        rm -f tmp/* 2>/dev/null
        ( ./cleanup.sh ) >/dev/null 2>&1; rc=$?
        expect_eq "cleanup.sh exit status" "$rc" 3
        got="$(find tmp -mindepth 1 | wc -l)"
        if (( got == 0 )); then ok "cleanup.sh left nothing behind in tmp/ (EXIT trap ran on the failure path)"
        else bad "cleanup.sh left $got file(s) in tmp/ — the EXIT trap did not run, or ran too late"; fi
    fi
}

solve() {
    cat > pipeline.sh <<'EOF'
#!/usr/bin/env bash
# print the first three ERROR lines of $1, sorted — and FAIL when grep fails
set -o pipefail
trap 'echo "ERROR: line $LINENO: $BASH_COMMAND" >&2' ERR
grep ERROR "$1" | LC_ALL=C sort | head -3
EOF
    cat > status.sh <<'EOF'
#!/usr/bin/env bash
false | true | false
echo "${PIPESTATUS[@]}"      # must be the very next command — anything else overwrites it
EOF
    cat > cleanup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p tmp
tmp=$(mktemp ./tmp/work.XXXXXX)
trap 'rm -f -- "$tmp"' EXIT          # runs on success, failure and `exit`
echo "working in $tmp"
(exit 3)                             # the failing step; set -e exits with its status
EOF
    chmod +x pipeline.sh status.sh cleanup.sh
}
