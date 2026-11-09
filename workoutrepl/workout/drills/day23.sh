# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day23 — rsync semantics
DRILL_TITLE="rsync — the trailing slash, -a, --exclude, --delete, and -n before anything destructive"
DRILL_WEEK=4
DRILL_TOOLS=(rsync)

brief() {
    cat <<'EOF'
src/ is a project tree; src-v2/ is the same project a day later (one file changed, one
removed, one added). Produce four destinations with rsync:

1. mirror-a/  — the CONTENTS of src/ (so mirror-a/README.md exists).  rsync -a src/ mirror-a
2. mirror-b/  — src/ itself INSIDE it (so mirror-b/src/README.md exists). rsync -a src mirror-b
   (one character of difference; this is the whole lesson)
3. mirror-x/  — the contents of src/ WITHOUT any *.tmp file and without the cache/ dir.
4. synced/    — first synced from src/, then synced from src-v2/ with --delete, so that
   it equals src-v2/ exactly: stale.txt gone, new.txt present, notes.md updated.
   Do a `-n` (dry run) with -v or -i first and READ what it would delete.

The checker compares trees with diff -r and checks that mirror-a and mirror-x preserved
the executable bit on bin/run.sh (-a implies -p).

Why: rsync is the backup tool, and `src` vs `src/` is the mistake that puts a backup
inside a backup. --delete makes a mirror honest and makes a typo catastrophic — so the
reflex is -n first, every time. One more thing worth knowing: rsync decides "unchanged"
by SIZE and MTIME (the quick check) — a same-size edit within the same second is
invisible to it unless you pass -c (checksum) or -I.
EOF
}

hint() {
    cat <<'EOF'
rsync -a src/ mirror-a/            # "the contents of src"
rsync -a src  mirror-b/            # "src, as a directory, into mirror-b"
rsync -a --exclude='*.tmp' --exclude='cache/' src/ mirror-x/
rsync -a src/ synced/; rsync -an --delete -i src-v2/ synced/; rsync -a --delete src-v2/ synced/
EOF
}

setup() {
    mkdir -p src/bin src/docs src/cache
    mkfile src/README.md '# project'
    mkfile src/notes.md 'day one'
    mkfile src/stale.txt 'to be removed in v2'
    mkfile src/bin/run.sh '#!/bin/sh' 'echo run'; chmod 755 src/bin/run.sh
    mkfile src/docs/guide.md 'guide'
    mkfile src/scratch.tmp 'temp'
    mkfile src/cache/blob.bin 'cache'
    cp -a src src-v2
    rm -f src-v2/stale.txt
    mkfile src-v2/notes.md 'day two, revised'
    mkfile src-v2/new.txt 'added in v2'
    # rsync's quick check is SIZE + MTIME: a same-size edit in the same second as the copy
    # would look unchanged. Pin the mtimes a day apart so the fixture means what it says.
    find src -exec touch -d '2024-05-01 09:00' {} +
    find src-v2 -exec touch -d '2024-05-02 09:00' {} +
}

check() {
    local expect_a; expect_a="$PWD/.expect"
    rm -rf "$expect_a"; mkdir -p "$expect_a"
    cp -a src "$expect_a/contents"
    expect_same_tree "$expect_a/contents" mirror-a "mirror-a/ (contents of src/)"
    [[ -d mirror-b/src ]] && expect_same_tree "$expect_a/contents" mirror-b/src "mirror-b/src (src/ placed inside)" || bad "mirror-b/src does not exist — without the trailing slash rsync copies the directory itself"
    [[ -e mirror-b/README.md ]] && bad "mirror-b/README.md exists — the contents were copied, not the directory" || ok "mirror-b/ holds src/ as a directory, not its contents"
    cp -a src "$expect_a/filtered"; rm -rf "$expect_a/filtered/cache" "$expect_a/filtered/scratch.tmp"
    expect_same_tree "$expect_a/filtered" mirror-x "mirror-x/ (no *.tmp, no cache/)"
    expect_same_tree src-v2 synced "synced/ (equal to src-v2 after --delete)"
    expect_no_path synced/stale.txt "synced/stale.txt (deleted by --delete)"
    expect_mode mirror-a/bin/run.sh 755
    expect_mode mirror-x/bin/run.sh 755
    rm -rf "$expect_a"
}

solve() {
    rsync -a src/ mirror-a/
    rsync -a src  mirror-b/
    rsync -a --exclude='*.tmp' --exclude='cache/' src/ mirror-x/
    rsync -a src/ synced/
    rsync -an --delete -i src-v2/ synced/ > dry-run.txt     # read this before the real one
    rsync -a --delete src-v2/ synced/
}
