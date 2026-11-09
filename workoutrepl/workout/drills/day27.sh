# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day27 — Robust scripts and logging
DRILL_TITLE="backup.sh — set -Eeuo pipefail, a dry run, timestamped logs, idempotence, loud failure"
DRILL_WEEK=4
DRILL_TOOLS=(rsync)

brief() {
    cat <<'EOF'
Write backup.sh [--dry-run] SRC DEST — the honest backup script:

  • copies SRC/ into DEST/data/ with rsync -a --delete;
  • appends to DEST/backup.log one line per event, formatted
        YYYY-MM-DDTHH:MM:SS LEVEL message        (date +%FT%T; LEVEL is INFO or ERROR)
    with at least an INFO line at start (`start src=… dest=…`) and one at the end
    (`done files=N` where N is the number of regular files now under DEST/data);
  • --dry-run writes NOTHING at all — no data, no log file (print what it would do to
    stdout instead; rsync -n is your friend);
  • exits 0 and is idempotent: a second run changes nothing under DEST/data (compare
    with diff -r) and adds only new log lines;
  • when SRC does not exist: exits non-zero, writes an ERROR line to the log, and
    prints the error on stderr;
  • uses set -Eeuo pipefail and an ERR trap so that an unexpected failure anywhere is
    logged as ERROR before the script dies — the checker makes rsync fail by making one
    SOURCE file unreadable (chmod 000) and expects an ERROR line and a non-zero exit.

Why: this is the shape of the script the article's author said he gained the most
from — and it is the shape of every script that runs when nobody is watching. A log
line with a timestamp and a level, a dry run, idempotence and a loud failure are what
let you trust it at 02:30.
EOF
}

hint() {
    cat <<'EOF'
set -Eeuo pipefail
log() { printf '%s %s %s\n' "$(date +%FT%T)" "$1" "${*:2}" >> "$dest/backup.log"; }
trap 'log ERROR "failed at line $LINENO: $BASH_COMMAND"' ERR      # -E makes ERR fire inside functions
[[ -d $src ]] || { log ERROR "source missing: $src"; echo "source missing: $src" >&2; exit 1; }
(( dry )) && { rsync -an --delete "$src/" "$dest/data/"; exit 0; }
EOF
}

setup() {
    mkdir -p src/docs
    mkfile src/a.txt 'alpha'; mkfile src/b.txt 'beta'; mkfile src/docs/c.md 'gamma'
}

_logfmt='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} (INFO|ERROR) '
check() {
    expect_executable backup.sh
    [[ -x backup.sh ]] || return
    local rc out before after lines1 lines2
    rm -rf dest src2
    out="$(./backup.sh --dry-run src dest 2>&1)"; rc=$?
    expect_eq "--dry-run exit status" "$rc" 0
    [[ ! -e dest ]] && ok "--dry-run wrote nothing (dest/ does not exist)" || bad "--dry-run created dest/ — a dry run must not write"
    ( ./backup.sh src dest ) >/dev/null 2>&1; rc=$?
    expect_eq "backup.sh src dest exit status" "$rc" 0
    expect_same_tree src dest/data "dest/data (== src)"
    if [[ -f dest/backup.log ]]; then
        [[ -n "$(grep -vE "$_logfmt" dest/backup.log)" ]] && bad "backup.log has lines not in 'YYYY-MM-DDTHH:MM:SS LEVEL msg' format: $(grep -vE "$_logfmt" dest/backup.log | head -1)" || ok "every backup.log line is timestamped with a level"
        expect_grep dest/backup.log ' INFO start ' "backup.log start line"
        expect_grep dest/backup.log ' INFO done files=3$' "backup.log 'done files=3'"
    else bad "dest/backup.log is missing"; return; fi
    before="$(cd dest/data && find . -printf '%p %s %m\n' | sort)"; lines1="$(wc -l < dest/backup.log)"
    ( ./backup.sh src dest ) >/dev/null 2>&1
    after="$(cd dest/data && find . -printf '%p %s %m\n' | sort)"; lines2="$(wc -l < dest/backup.log)"
    [[ "$before" == "$after" ]] && ok "second run changed nothing under dest/data" || bad "a second run changed dest/data"
    (( lines2 > lines1 )) && ok "second run appended to the log ($lines1 → $lines2 lines)" || bad "second run did not log"
    out="$(./backup.sh no-such-src dest 2>&1 >/dev/null)"; ( ./backup.sh no-such-src dest ) >/dev/null 2>&1; rc=$?
    (( rc != 0 )) && ok "missing SRC exits non-zero ($rc)" || bad "missing SRC exited 0"
    [[ -n "$out" ]] && ok "missing SRC reports on stderr" || bad "missing SRC printed nothing on stderr"
    expect_grep dest/backup.log ' ERROR .*no-such-src' "backup.log ERROR line naming the missing source"
    # an UNEXPECTED failure: one source file rsync cannot read (rsync exits 23)
    # (not an unwritable dest/data — rsync -a owns that directory and simply chmods it back)
    mkdir -p src2; cp -a src/. src2/; mkfile src2/secret.txt 'unreadable'; chmod 000 src2/secret.txt
    lines1="$(grep -c ' ERROR ' dest/backup.log)"
    ( ./backup.sh src2 dest ) >/dev/null 2>&1; rc=$?
    chmod 644 src2/secret.txt
    (( rc != 0 )) && ok "rsync failure makes backup.sh exit non-zero ($rc)" || bad "backup.sh exited 0 although rsync could not read a source file (set -e / pipefail missing?)"
    lines2="$(grep -c ' ERROR ' dest/backup.log)"
    (( lines2 > lines1 )) && ok "rsync failure was logged as ERROR (ERR trap)" || bad "no ERROR line was logged for the rsync failure — trap … ERR with set -E"
    rm -rf src2
}

solve() {
    cat > backup.sh <<'EOF'
#!/usr/bin/env bash
# backup.sh [--dry-run] SRC DEST — rsync SRC/ into DEST/data/, log to DEST/backup.log
set -Eeuo pipefail
dry=0
[[ ${1-} == --dry-run ]] && { dry=1; shift; }
src=${1:?usage: backup.sh [--dry-run] SRC DEST} dest=${2:?DEST}
log() {                                   # log LEVEL message...
    (( dry )) && return 0                 # a dry run writes nothing, not even a log
    printf '%s %s %s\n' "$(date +%FT%T)" "$1" "${*:2}" >> "$dest/backup.log"
}
trap 'log ERROR "failed at line $LINENO: $BASH_COMMAND"' ERR   # -E: fires inside functions too
if [[ ! -d $src ]]; then
    mkdir -p -- "$dest" 2>/dev/null || true
    log ERROR "source missing: $src"
    printf 'backup.sh: source missing: %s\n' "$src" >&2
    exit 1
fi
if (( dry )); then
    printf 'DRY RUN: would sync %s/ -> %s/data/\n' "$src" "$dest"
    rsync -an --delete -i -- "$src/" "$dest/data/" 2>/dev/null || true
    exit 0
fi
mkdir -p -- "$dest/data"
log INFO "start src=$src dest=$dest"
rsync -a --delete -- "$src/" "$dest/data/"
count=$(find "$dest/data" -type f | wc -l)
log INFO "done files=$count"
EOF
    chmod +x backup.sh
}
