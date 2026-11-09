# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day26 — Scheduling: systemd timers, cron, and a lock against overlap
DRILL_TITLE="Scheduling — a systemd timer+service pair, a crontab line, and flock against overlapping runs"
DRILL_WEEK=4
DRILL_TOOLS=(flock systemd-analyze)

brief() {
    cat <<'EOF'
Three artifacts, no root required (nothing is installed — they are validated as files):

1. backup.timer + backup.service — a user-level pair that would run /home/learner/bin/
   backup.sh every WEEKDAY at 02:30.
     backup.timer   [Unit] Description=…  [Timer] OnCalendar=<expr>  Persistent=true
                    [Install] WantedBy=timers.target
     backup.service [Unit] Description=…  [Service] Type=oneshot  ExecStart=<ABSOLUTE path>
   The checker normalises your OnCalendar with `systemd-analyze calendar` and expects
   exactly  Mon..Fri *-*-* 02:30:00  — several spellings normalise to that; pick one.

2. cron.txt — ONE crontab line that runs /home/learner/bin/backup.sh every 15 minutes
   between 09:00 and 17:59 on weekdays. The checker parses the five fields: minute must
   be */15 or 0,15,30,45; hour 9-17; day-of-week 1-5 (or Mon-Fri).

3. with-lock.sh CMD... — runs CMD under a NON-BLOCKING lock on run/lock (flock -n): if
   another instance holds the lock, print `already running` to stderr and exit 75
   (EX_TEMPFAIL) immediately; otherwise run CMD and exit with ITS status. The checker
   holds the lock from a background process and asserts the 75.

Why: a scheduled job that takes longer than its interval overlaps itself — two rsyncs
into one destination, two writers on one database. The lock is not optional. And
`systemd-analyze calendar` is how you find out what your OnCalendar MEANS before 02:30
tells you.
EOF
}

hint() {
    cat <<'EOF'
systemd-analyze calendar 'Mon..Fri 02:30'           # prints the normalized form and the next elapse
*/15 9-17 * * 1-5 /home/learner/bin/backup.sh
exec 9> run/lock; flock -n 9 || { echo 'already running' >&2; exit 75; }; "$@"
EOF
}

setup() { mkdir -p run; }

check() {
    local v norm out rc err f1 f2 f3 f4 f5 cmd
    expect_file backup.timer; expect_file backup.service
    if [[ -f backup.timer ]]; then
        v="$(sed -n 's/^OnCalendar=//p' backup.timer | head -1)"
        if [[ -z "$v" ]]; then bad "backup.timer has no OnCalendar= line"
        elif have systemd-analyze; then
            norm="$(systemd-analyze calendar "$v" 2>/dev/null | sed -n 's/^ *Normalized form: *//p')"
            expect_eq "OnCalendar '$v' normalises to" "$norm" "Mon..Fri *-*-* 02:30:00"
        else unknown "systemd-analyze is not installed, so OnCalendar='$v' was not normalised and checked"; fi
        expect_grep backup.timer '^Persistent=true$' "backup.timer Persistent=true"
        expect_grep backup.timer '^WantedBy=timers.target$' "backup.timer WantedBy=timers.target"
        expect_grep backup.timer '^\[Timer\]$' "backup.timer [Timer] section"
    fi
    if [[ -f backup.service ]]; then
        expect_grep backup.service '^Type=oneshot$' "backup.service Type=oneshot"
        expect_grep backup.service '^ExecStart=/' "backup.service ExecStart= is an absolute path"
    fi
    if [[ -f cron.txt ]]; then
        read -r f1 f2 f3 f4 f5 cmd < <(grep -vE '^\s*(#|$)' cron.txt | head -1)
        [[ "${f1:-}" == '*/15' || "${f1:-}" == '0,15,30,45' ]] && ok "cron minute field: $f1" || bad "cron minute field should be */15 (or 0,15,30,45), got '${f1:-}'"
        expect_eq "cron hour field" "${f2:-}" "9-17"
        expect_eq "cron day-of-month" "${f3:-}" "*"; expect_eq "cron month" "${f4:-}" "*"
        [[ "${f5:-}" == "1-5" || "${f5,,}" == "mon-fri" ]] && ok "cron weekday field: $f5" || bad "cron weekday field should be 1-5 or Mon-Fri, got '${f5:-}'"
        expect_eq "cron command" "${cmd:-}" "/home/learner/bin/backup.sh"
    else bad "cron.txt is missing"; fi
    expect_executable with-lock.sh
    if [[ -x with-lock.sh ]]; then
        rm -f run/lock
        out="$(./with-lock.sh echo hello 2>/dev/null)"
        expect_eq "with-lock.sh echo hello (unlocked) output" "$out" "hello"
        expect_eq "with-lock.sh passes through the command's status" "$(./with-lock.sh sh -c 'exit 4' >/dev/null 2>&1; echo $?)" 4
        flock run/lock sleep 2 &
        local holder=$!; sleep 0.3
        err="$(./with-lock.sh echo nope 2>&1 >/dev/null)"; ./with-lock.sh echo nope >/dev/null 2>&1; rc=$?
        expect_eq "with-lock.sh while another holds the lock exits EX_TEMPFAIL" "$rc" 75
        expect_match "with-lock.sh reports on stderr" "$err" 'already running'
        kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
    fi
}

solve() {
    cat > backup.timer <<'EOF'
[Unit]
Description=Nightly backup (weekdays, 02:30)

[Timer]
OnCalendar=Mon..Fri *-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    cat > backup.service <<'EOF'
[Unit]
Description=Nightly backup

[Service]
Type=oneshot
ExecStart=/home/learner/bin/backup.sh
EOF
    printf '%s\n' '*/15 9-17 * * 1-5 /home/learner/bin/backup.sh' > cron.txt
    cat > with-lock.sh <<'EOF'
#!/usr/bin/env bash
# with-lock.sh CMD... — run CMD unless another instance holds run/lock
set -uo pipefail
mkdir -p run
exec 9> run/lock                       # the lock lives on an fd, so it dies with us
if ! flock -n 9; then
    echo 'already running' >&2
    exit 75                            # EX_TEMPFAIL: try again later
fi
"$@"
EOF
    chmod +x with-lock.sh
}
