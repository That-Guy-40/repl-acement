# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day17 — Here-docs, mktemp, atomic writes
DRILL_TITLE="Here-documents, here-strings, mktemp and the atomic rename"
DRILL_WEEK=3
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
Three scripts about getting text in and out of files without surprises:

1. gen-config.sh NAME PORT — writes NAME.conf from a here-document that interpolates
   NAME and PORT but ALSO contains the literal text  $HOME  and  $(hostname)  which must
   appear verbatim in the output (not expanded). Expected content for `gen-config.sh web 8080`:
       # generated for web
       name = web
       port = 8080
       home = $HOME
       host = $(hostname)
   (one trick: an unquoted delimiter with \$ escapes — or two here-docs, one quoted.)

2. atomic-update.sh FILE — replaces FILE with an UPPER-CASED copy of itself, atomically:
   write to a temp file created by mktemp IN THE SAME DIRECTORY as FILE, then mv it
   over FILE. Properties the checker asserts:
     • content is upper-cased and the file's permission bits are preserved (chmod
       --reference or cp -p the mode before the mv)
     • the inode CHANGES (it is a rename, not an in-place write)
     • when FILE does not exist the script exits non-zero and leaves NO temp file
       behind in that directory (an EXIT trap)
     • no temp file is left behind on success either

3. csv-count.sh — reads the environment variable FIELDS (comma-separated) and prints
   `n=<count>` followed by one `field=<value>` line per field, splitting with
   `read -ra` on a HERE-STRING (<<<) and IFS=, — no tr, no awk.
   FIELDS='a,b b,c' → n=3 / field=a / field=b b / field=c

Why: a half-written config file read by another process is a real outage; rename(2)
is atomic on one filesystem, which is why the temp file must live beside its target.
Quoted vs unquoted here-doc delimiters are the whole difference between a template
and a program.
EOF
}

hint() {
    cat <<'EOF'
cat > "$name.conf" <<EOF2
# generated for $name
home = \$HOME
host = \$(hostname)
EOF2
tmp=$(mktemp "$(dirname -- "$file")/.tmp.XXXXXX"); trap 'rm -f -- "$tmp"' EXIT
tr a-z A-Z < "$file" > "$tmp" && chmod --reference="$file" "$tmp" && mv -- "$tmp" "$file"
IFS=, read -ra f <<<"$FIELDS"; echo "n=${#f[@]}"
EOF
}

setup() { mkdir -p data; printf 'hello\nworld\n' > data/greeting.txt; chmod 640 data/greeting.txt; }

check() {
    local out rc ino1 ino2
    expect_executable gen-config.sh
    if [[ -x gen-config.sh ]]; then
        rm -f web.conf; ./gen-config.sh web 8080 >/dev/null 2>&1
        expect_content web.conf $'# generated for web\nname = web\nport = 8080\nhome = $HOME\nhost = $(hostname)\n' "web.conf (interpolated AND literal)"
    fi
    expect_executable atomic-update.sh
    if [[ -x atomic-update.sh ]]; then
        printf 'hello\nworld\n' > data/greeting.txt; chmod 640 data/greeting.txt
        ino1="$(stat -c %i data/greeting.txt)"
        ( ./atomic-update.sh data/greeting.txt ) >/dev/null 2>&1; rc=$?
        expect_eq "atomic-update.sh exit status" "$rc" 0
        expect_content data/greeting.txt $'HELLO\nWORLD\n' "data/greeting.txt (upper-cased)"
        ino2="$(stat -c %i data/greeting.txt)"
        [[ "$ino1" != "$ino2" ]] && ok "inode changed ($ino1 → $ino2): the file was replaced by rename, not rewritten in place" || bad "inode unchanged — the file was written in place, so a reader could see it half-written"
        expect_mode data/greeting.txt 640
        out="$(find data -mindepth 1 -maxdepth 1 ! -name greeting.txt | wc -l)"
        expect_eq "temp files left in data/ after success" "$out" 0
        ( ./atomic-update.sh data/does-not-exist.txt ) >/dev/null 2>&1; rc=$?
        (( rc != 0 )) && ok "a missing FILE exits non-zero ($rc)" || bad "a missing FILE exited 0"
        out="$(find data -mindepth 1 -maxdepth 1 ! -name greeting.txt | wc -l)"
        expect_eq "temp files left in data/ after the failure" "$out" 0
    fi
    expect_executable csv-count.sh
    if [[ -x csv-count.sh ]]; then
        out="$(FIELDS='a,b b,c' ./csv-count.sh 2>/dev/null)"; expect_eq "csv-count.sh with FIELDS='a,b b,c'" "$out" $'n=3\nfield=a\nfield=b b\nfield=c'
        out="$(FIELDS='solo' ./csv-count.sh 2>/dev/null)";    expect_eq "csv-count.sh with one field" "$out" $'n=1\nfield=solo'
    fi
}

solve() {
    cat > gen-config.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name=${1:?NAME} port=${2:?PORT}
cat > "$name.conf" <<CONF
# generated for $name
name = $name
port = $port
home = \$HOME
host = \$(hostname)
CONF
EOF
    cat > atomic-update.sh <<'EOF'
#!/usr/bin/env bash
# atomic-update.sh FILE — replace FILE with its upper-cased self via a same-directory temp + rename
set -euo pipefail
file=${1:?usage: atomic-update.sh FILE}
[[ -f $file ]] || { printf 'no such file: %s\n' "$file" >&2; exit 1; }
dir=$(dirname -- "$file")
tmp=$(mktemp "$dir/.update.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT               # on any exit path, the temp file goes
tr a-z A-Z < "$file" > "$tmp"
chmod --reference="$file" "$tmp"
mv -f -- "$tmp" "$file"                   # rename(2): readers see old or new, never half
EOF
    cat > csv-count.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
IFS=, read -ra fields <<<"${FIELDS:?set FIELDS=a,b,c}"
printf 'n=%d\n' "${#fields[@]}"
printf 'field=%s\n' "${fields[@]}"
EOF
    chmod +x gen-config.sh atomic-update.sh csv-count.sh
}
