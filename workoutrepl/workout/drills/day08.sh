# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day08 — grep beyond the basics
DRILL_TITLE="grep — -c -l -L -o -w -x, context, recursion with --include, fixed strings from a file"
DRILL_WEEK=2
DRILL_TOOLS=(grep)

brief() {
    cat <<'EOF'
logs/ holds three app logs, a notes file and a nested old log. Produce six files, each
from grep (plus sort/sed where needed) — no awk, no loops:

1. errors-count.txt   one `path:count` line per *.log file under logs/ (recursively),
                      counting lines containing the WORD ERROR (not Error, not ERRORS),
                      including files with 0, sorted by path.          (-r --include -c -w)
2. with-timeout.txt   paths of files (any type, under logs/) that contain `timeout`
                      case-insensitively, sorted.                        (-r -l -i)
3. without-timeout.txt  the paths that do NOT, sorted.                  (-L)
4. ips.txt            every distinct IPv4 address appearing anywhere under logs/,
                      one per line, sorted — the ADDRESS only, not the line.  (-o -h)
5. context.txt        the single FATAL line in logs/ with ONE line of context before
                      and after it, exactly as grep prints them (no filename prefix).
6. disk.txt           `path:line` for every line containing the whole word `disk`
                      (any case) under logs/, in grep's own output order with -r
                      replaced by a sorted result.                        (-rniw)

Why: fluent grep is about the flags that change WHAT it prints — a count, a filename, a
match, a context window — so the next command in the pipe gets exactly the shape it
wants and sed/awk never have to be reached for.
EOF
}

hint() {
    cat <<'EOF'
grep -rcw --include='*.log' ERROR logs | sort
grep -rli timeout logs | sort        /  grep -rLi timeout logs | sort
grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' logs | sort -u
grep -rh -B1 -A1 FATAL logs
EOF
}

setup() {
    mkfile logs/app-1.log \
        "2024-03-01 10:00:01 INFO  server started on 10.0.0.5:8080" \
        "2024-03-01 10:00:07 ERROR disk quota exceeded for user ada" \
        "2024-03-01 10:01:00 WARN  Error rate rising (soft)" \
        "2024-03-01 10:02:15 ERROR connection timeout to 192.168.1.20" \
        "2024-03-01 10:03:00 INFO  client 10.0.0.9 connected"
    mkfile logs/app-2.log \
        "2024-03-02 09:00:00 INFO  server started on 10.0.0.5:8080" \
        "2024-03-02 09:10:00 INFO  Disk check passed" \
        "2024-03-02 09:11:00 ERRORS are not errors (this line must not count)" \
        "2024-03-02 09:12:00 INFO  client 172.16.0.3 connected"
    mkfile logs/app-3.log \
        "2024-03-03 08:00:00 INFO  starting" \
        "2024-03-03 08:00:01 ERROR DISK read failure on /dev/sdb" \
        "2024-03-03 08:00:02 FATAL cannot continue, halting" \
        "2024-03-03 08:00:03 INFO  shutdown complete" \
        "2024-03-03 08:00:04 ERROR TIMEOUT waiting for 10.0.0.9"
    mkfile logs/notes.txt "ops notes" "the diskette joke does not count as disk" "watch for a timeout on the 10.0.0.5 box"
    mkfile logs/old/archive.log "2023-12-31 23:59:59 INFO  rotated" "2023-12-31 23:59:59 ERROR legacy disk error from 192.168.1.20"
}

check() {
    expect_lines errors-count.txt $'logs/app-1.log:2\nlogs/app-2.log:0\nlogs/app-3.log:2\nlogs/old/archive.log:1' \
        "errors-count.txt (ERRORS and Error must not count — -w and case matter)"
    expect_lines with-timeout.txt $'logs/app-1.log\nlogs/app-3.log\nlogs/notes.txt' "with-timeout.txt"
    expect_lines without-timeout.txt $'logs/app-2.log\nlogs/old/archive.log' "without-timeout.txt"
    expect_lines ips.txt $'10.0.0.5\n10.0.0.9\n172.16.0.3\n192.168.1.20' "ips.txt (addresses only, deduplicated)"
    expect_lines context.txt $'2024-03-03 08:00:01 ERROR DISK read failure on /dev/sdb\n2024-03-03 08:00:02 FATAL cannot continue, halting\n2024-03-03 08:00:03 INFO  shutdown complete' \
        "context.txt (-B1 -A1 around FATAL, no filename)"
    expect_lines disk.txt $'logs/app-1.log:2:2024-03-01 10:00:07 ERROR disk quota exceeded for user ada\nlogs/app-2.log:2:2024-03-02 09:10:00 INFO  Disk check passed\nlogs/app-3.log:2:2024-03-03 08:00:01 ERROR DISK read failure on /dev/sdb\nlogs/notes.txt:2:the diskette joke does not count as disk\nlogs/old/archive.log:2:2023-12-31 23:59:59 ERROR legacy disk error from 192.168.1.20' \
        "disk.txt (whole word, any case, with path and line number)"
}

solve() {
    grep -rcw --include='*.log' ERROR logs | LC_ALL=C sort > errors-count.txt
    grep -rli timeout logs | LC_ALL=C sort > with-timeout.txt
    grep -rLi timeout logs | LC_ALL=C sort > without-timeout.txt
    grep -rhoE '([0-9]{1,3}\.){3}[0-9]{1,3}' logs | LC_ALL=C sort -u > ips.txt
    grep -rh -B1 -A1 FATAL logs > context.txt
    grep -rniw disk logs | LC_ALL=C sort > disk.txt
}
