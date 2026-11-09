# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day07 — BOSS 1: Cobalt Beluga — tidy a hostile download directory
DRILL_TITLE="tidy.sh — sort a hostile download directory by type and month, safely, idempotently"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
⚔ BOSS BATTLE 1 — everything from week 1 in one script.

downloads/ holds 14 files with mixed-case names, spaces, a leading `--`, a newline, a
dot-file, two in-progress `.part` downloads, and one pair of files with IDENTICAL
content. Their mtimes span 2024-01 .. 2024-03 (look with `ls -la --time-style=long-iso`).

Write tidy.sh so that `./tidy.sh downloads` :

  • moves every regular file into  downloads/sorted/<ext>/<YYYY-MM>/<name>
      where <ext> is the lower-cased extension (`noext` if none), <YYYY-MM> is the
      file's modification month, and <name> is the original name lower-cased with
      every space turned into `_`;
  • SKIPS *.part files (leaves them where they are);
  • when two files have identical content (compare with cmp or sha256sum), the one
    whose original name sorts FIRST is moved normally and the other goes to
    downloads/sorted/duplicates/<name> instead;
  • appends one line per file to downloads/tidy.log:
        MOVED <original name> -> <relative destination>
        SKIPPED <original name>
        DUPLICATE <original name> -> sorted/duplicates/<name>
  • is idempotent: running it a second time moves nothing and adds no MOVED or
    DUPLICATE lines (the files are already under sorted/, which it must not descend
    into; logging the .part files as SKIPPED again is fine);
  • never follows a name into an option (`--`), never splits a name on whitespace,
    and preserves every byte of every file (the checker compares contents).

Why a boss: this is the shape of every "organize my stuff" script people write, and
every one of them has eaten a file with a space in it. Yours will not.
EOF
}

hint() {
    cat <<'EOF'
for f in "$dir"/* "$dir"/.*; do [[ -f $f ]] || continue; …     # shopt -s dotglob nullglob is cleaner
month=$(date -r "$f" +%Y-%m)        # mtime → month;  stat -c %y works too
sum=$(sha256sum -- "$f" | cut -d' ' -f1); [[ -n ${seen[$sum]:-} ]] && dup=1; seen[$sum]=1
Process names in sorted order (`printf '%s\0' … | sort -z`) so "first" is well defined.
EOF
}

# name|mtime|content   — content "same" appears twice on purpose
_dl_spec() {
    cat <<'EOF'
Report Final.PDF|2024-01-15 09:00|pdf-one
holiday Photo.JPG|2024-02-03 12:00|jpg-one
IMG_0042.jpg|2024-02-04 12:00|jpg-two
invoice-march.pdf|2024-03-21 08:30|pdf-two
notes.TXT|2024-01-02 10:00|same
Notes copy.txt|2024-01-05 10:00|same
README|2024-03-01 00:00|noext-one
--weird name.txt|2024-02-10 10:00|txt-dash
setup.exe.part|2024-03-30 23:00|partial-one
movie.mkv.part|2024-03-30 23:30|partial-two
.secret.key|2024-01-20 15:00|dot-key
Tab	Separated.csv|2024-03-05 11:00|csv-tab
archive.TAR.GZ|2024-02-28 18:00|tgz-one
song.MP3|2024-01-31 23:59|mp3-one
EOF
}
setup() {
    mkdir -p downloads
    local name mtime content
    while IFS='|' read -r name mtime content; do
        printf '%s\n' "$content" > "downloads/$name"
        touch -d "$mtime" -- "downloads/$name"
    done < <(_dl_spec)
    # the newline-in-a-name case cannot ride the |-separated spec, so it is added here
    printf '%s\n' 'nl-one' > $'downloads/two\nlines.txt'
    touch -d '2024-02-14 14:00' -- $'downloads/two\nlines.txt'
}

# the expected destination of each file, relative to downloads/
_expected() {
    cat <<'EOF'
sorted/pdf/2024-01/report_final.pdf|pdf-one
sorted/jpg/2024-02/holiday_photo.jpg|jpg-one
sorted/jpg/2024-02/img_0042.jpg|jpg-two
sorted/pdf/2024-03/invoice-march.pdf|pdf-two
sorted/txt/2024-01/notes_copy.txt|same
sorted/duplicates/notes.txt|same
sorted/noext/2024-03/readme|noext-one
sorted/txt/2024-02/--weird_name.txt|txt-dash
sorted/key/2024-01/.secret.key|dot-key
sorted/csv/2024-03/tab	separated.csv|csv-tab
sorted/gz/2024-02/archive.tar.gz|tgz-one
sorted/mp3/2024-01/song.mp3|mp3-one
EOF
}
check() {
    expect_executable tidy.sh
    local p c
    while IFS='|' read -r p c; do
        if [[ -f "downloads/$p" ]]; then
            [[ "$(cat "downloads/$p")" == "$c" ]] && ok "$(printf '%q' "$p") — right place, content intact" || bad "$(printf '%q' "$p") has the wrong content (expected '$c')"
        else bad "expected $(printf '%q' "downloads/$p") — not found"; fi
    done < <(_expected)
    local nl=$'sorted/txt/2024-02/two\nlines.txt'
    [[ -f "downloads/$nl" && "$(cat "downloads/$nl")" == nl-one ]] && ok "the newline-named file arrived whole" || bad "the file whose name contains a newline was lost or mangled (expected $(printf '%q' "$nl"))"
    expect_file downloads/setup.exe.part "setup.exe.part (skipped, left in place)"
    expect_file downloads/movie.mkv.part "movie.mkv.part (skipped, left in place)"
    local stray; stray="$(find downloads -maxdepth 1 -type f ! -name '*.part' ! -name tidy.log -print0 | tr -cd '\0' | wc -c)"
    expect_eq "files left loose in downloads/ (besides .part and the log)" "$stray" 0
    if [[ -f downloads/tidy.log ]]; then
        expect_eq "tidy.log MOVED lines"     "$(grep -c '^MOVED '     downloads/tidy.log)" 12
        expect_eq "tidy.log DUPLICATE lines" "$(grep -c '^DUPLICATE ' downloads/tidy.log)" 1
        # the brief allows a re-run to log the .part files as SKIPPED again, so this is
        # "both .part files were logged", not "exactly two lines" (found via repl/: a second
        # save re-runs the script, and an exact 2 failed a correct tidy.sh)
        local sk; sk="$(grep -c '^SKIPPED ' downloads/tidy.log)"
        if (( sk >= 2 )) && grep -q '^SKIPPED setup.exe.part$' downloads/tidy.log && grep -q '^SKIPPED movie.mkv.part$' downloads/tidy.log; then
            ok "tidy.log SKIPPED lines: both .part files logged ($sk line(s); a re-run may log them again)"
        else bad "tidy.log SKIPPED lines: expected setup.exe.part and movie.mkv.part each logged as SKIPPED, got $sk SKIPPED line(s)"; fi
    else bad "downloads/tidy.log is missing"; fi
    # idempotence: a second run must change nothing
    if [[ -x tidy.sh && -f downloads/tidy.log ]]; then
        local before after
        before="$(find downloads -print0 | sort -z | tr '\0' '\n'; grep -cE '^(MOVED|DUPLICATE) ' downloads/tidy.log)"
        ( ./tidy.sh downloads ) >/dev/null 2>&1
        after="$(find downloads -print0 | sort -z | tr '\0' '\n'; grep -cE '^(MOVED|DUPLICATE) ' downloads/tidy.log)"
        [[ "$before" == "$after" ]] && ok "second run moved nothing and logged no new MOVED/DUPLICATE (idempotent)" || bad "a second run moved files or logged new MOVED/DUPLICATE lines — it must ignore sorted/ and already-tidied state"
    fi
}

solve() {
    cat > tidy.sh <<'EOF'
#!/usr/bin/env bash
# tidy.sh DIR — sort DIR's loose files into DIR/sorted/<ext>/<YYYY-MM>/, safely
set -euo pipefail
dir=${1:?usage: tidy.sh DIR}
log="$dir/tidy.log"
declare -A seen                      # content hash → already placed
shopt -s dotglob nullglob
# Collect the loose files in a well-defined order (so "first duplicate" is stable),
# NUL-separated because one of the names contains a newline.
mapfile -d '' files < <(printf '%s\0' "$dir"/* | LC_ALL=C sort -z)
for f in "${files[@]}"; do
    [[ -f $f ]] || continue                       # skip sorted/ and anything else that is not a file
    name=${f##*/}
    [[ $name == tidy.log ]] && continue
    if [[ $name == *.part ]]; then printf 'SKIPPED %s\n' "$name" >> "$log"; continue; fi
    lower=${name,,}; lower=${lower// /_}
    if [[ $lower == *.* && $lower != .* ]] || [[ $lower == .*.* ]]; then ext=${lower##*.}; else ext=noext; fi
    sum=$(sha256sum -- "$f" | cut -d' ' -f1)
    if [[ -n ${seen[$sum]:-} ]]; then
        dest="sorted/duplicates/$lower"
        mkdir -p -- "$dir/sorted/duplicates"
        mv -n -- "$f" "$dir/$dest"
        printf 'DUPLICATE %s -> %s\n' "$name" "$dest" >> "$log"
        continue
    fi
    seen[$sum]=1
    month=$(date -r "$f" +%Y-%m)
    dest="sorted/$ext/$month/$lower"
    mkdir -p -- "$dir/sorted/$ext/$month"
    mv -n -- "$f" "$dir/$dest"
    printf 'MOVED %s -> %s\n' "$name" "$dest" >> "$log"
done
EOF
    chmod +x tidy.sh
    ./tidy.sh downloads
}
