#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  integration/01_runner.sh - what the OUTPUT pane runs on every save (_wr_run)
##  and what the CHECK pane runs when the stamp changes (_wr_check), called
##  directly against a scratch WORKOUT_HOME:
##    - a #DAY/#FILE/#RUN file builds the fixture on demand, writes the body
##      (executable when it starts with #!), runs #RUN, prints `# wrote:`,
##      `# command:` and `# exit:`, and stamps the day for the check pane
##    - the check pane grades that day and names the defect
##    - #DATA is the run's stdin; #FRESH rebuilds the fixture; #MODE is honoured
##    - no #DAY prints the hint and writes nothing; a #FILE that climbs out of
##      the fixture is refused and nothing is written
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$(cd "$TESTS_DIR/../.." && pwd)"
source "$TESTS_DIR/../helpers.sh"
source "$DIR/workoutrepl"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export WORKOUT_LIB="$DIR/workout" WORKOUT_HOME="$work/home/workout" TMPDIR="$work/tmp"
mkdir -p "$WORKOUT_HOME" "$TMPDIR"
WORKOUT="$WORKOUT_LIB/bin/workout"
replfile="$work/.repl.workout"; body="$work/body"; data="$work/data"; hdrs="$work/hdrs"; stamp="$work/stamp"
: > "$stamp"

run()   { _wr_run "$replfile" "$body" "$data" "$hdrs" "$stamp" "$WORKOUT" 2>&1; }
check() { _wr_check "$stamp" "$WORKOUT" 2>&1; }

# --- a day-7 piece: fixture built on demand, written, run, stamped ---
cat > "$replfile" <<'EOF'
# narration above the headers is not written anywhere
#DAY 7
#FILE tidy.sh
#RUN ./tidy.sh downloads
#!/usr/bin/env bash
echo "tidy.sh placeholder for $1"
exit 3
EOF
out=$(run)
assert_output_contains "the run names the day"                 "# day 07 ·"                 printf '%s' "$out"
assert_output_contains "the run reports the write"             "wrote:   day07/tidy.sh"     printf '%s' "$out"
assert_output_contains "…with mode 755 (body starts with #!)"  "(mode 755,"                 printf '%s' "$out"
assert_output_contains "the run shows the #RUN command"        "# command: ./tidy.sh downloads" printf '%s' "$out"
assert_output_contains "the piece's own output appears"        "tidy.sh placeholder for downloads" printf '%s' "$out"
assert_output_contains "the run shows the exit status"         "# exit:    3"               printf '%s' "$out"
if [[ -x "$WORKOUT_HOME/day07/tidy.sh" ]]; then
    pass "day07/tidy.sh was written into the fixture, executable"
else
    fail "day07/tidy.sh is missing or not executable in the fixture" "$(ls -la "$WORKOUT_HOME/day07" 2>&1)"
fi
if [[ -d "$WORKOUT_HOME/day07/downloads" ]]; then
    pass "the day-7 fixture was built on demand (downloads/ exists)"
else
    fail "the day-7 fixture was not built" "$(ls "$WORKOUT_HOME" 2>&1)"
fi
assert_equals "the stamp's first line hands day 7 to the check pane" "7" "$(head -1 "$stamp")"

# --- the check pane grades the stamped day and names the defect ---
out=$(check)
assert_output_contains "the check pane says which day it graded"  "# workout check 7"     printf '%s' "$out"
assert_output_contains "a placeholder tidy.sh fails day 7"        "FAIL: day 07"          printf '%s' "$out"
assert_output_contains "…and the failure names the defect"        "tidy.log is missing"   printf '%s' "$out"

# --- #DATA is the run's stdin; a non-.sh #FILE gets no default command; #MODE honoured ---
cat > "$replfile" <<'EOF'
#DAY 1
#FILE answers.txt
#MODE 600
#RUN cat; cat answers.txt
first answer
#DATA
fed on stdin
EOF
out=$(run)
assert_output_contains "#DATA reaches the run's stdin"        "fed on stdin"           printf '%s' "$out"
assert_output_contains "the body was written to answers.txt"  "first answer"           printf '%s' "$out"
assert_output_contains "…with the #MODE given"                "(mode 600,"             printf '%s' "$out"
assert_equals "the file's mode is 600" "600" "$(stat -c %a "$WORKOUT_HOME/day01/answers.txt")"
assert_equals "the stamp now says day 1" "1" "$(head -1 "$stamp")"

# --- a .sh #FILE without #RUN runs `bash ./FILE`; a timeout is reported as such ---
cat > "$replfile" <<'EOF'
#DAY 1
#FILE slow.sh
#TIMEOUT 1
sleep 5
EOF
out=$(run)
assert_output_contains "default command is bash ./FILE"       "# command: bash ./slow.sh"  printf '%s' "$out"
assert_output_contains "a run past #TIMEOUT is killed and said so" "# exit:    124 (killed after 1 s" printf '%s' "$out"

# --- #FRESH yes rebuilds the fixture before the write ---
touch "$WORKOUT_HOME/day01/left-over-from-last-run"
cat > "$replfile" <<'EOF'
#DAY 1
#FILE history.sh
#FRESH yes
echo fresh
EOF
out=$(run)
assert_output_contains "#FRESH announces the rebuild" "#FRESH: rebuilding the fixture first" printf '%s' "$out"
if [[ ! -e "$WORKOUT_HOME/day01/left-over-from-last-run" ]]; then
    pass "#FRESH rebuilt the fixture (the left-over file is gone)"
else
    fail "#FRESH did not rebuild the fixture: the left-over file survived"
fi
assert_file_contains "…and the piece was still written afterwards" "echo fresh" "$WORKOUT_HOME/day01/history.sh"

# --- no #DAY: the hint, nothing written, stamp untouched ---
before=$(cat "$stamp")
printf '# just a comment\necho x\n' > "$replfile"
out=$(run)
assert_output_contains "no #DAY prints the hint" "add a header line  #DAY N" printf '%s' "$out"
assert_equals "no #DAY leaves the stamp alone (the check pane is not woken)" "$before" "$(cat "$stamp")"

# --- #DAY that is not a day ---
printf '#DAY 99\n#FILE x.sh\necho x\n' > "$replfile"
out=$(run)
assert_output_contains "#DAY 99 is refused by name" "#DAY 99 is not a day" printf '%s' "$out"

# --- a #FILE that climbs out of the fixture is refused and nothing is written ---
printf '#DAY 1\n#FILE ../escaped.sh\necho x\n' > "$replfile"
out=$(run)
assert_output_contains "#FILE ../x is refused" "#FILE must be a relative path inside the fixture" printf '%s' "$out"
if [[ ! -e "$WORKOUT_HOME/escaped.sh" && ! -e "$WORKOUT_HOME/day01/../escaped.sh" ]]; then
    pass "…and nothing was written outside the fixture"
else
    fail "a #FILE with ../ wrote outside the fixture"
fi
printf '#DAY 1\n#FILE /tmp/escaped.sh\necho x\n' > "$replfile"
out=$(run)
assert_output_contains "an absolute #FILE is refused" "#FILE must be a relative path" printf '%s' "$out"

# the first run forks a one-off re-stamp (sleep 2) to beat entr's arming race; let it finish
sleep 2.5
summary
