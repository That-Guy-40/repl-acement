# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day12 — find and xargs
DRILL_TITLE="find and xargs — predicates, -newer, -size, -print0, -exec {} + versus \;"
DRILL_WEEK=2
DRILL_TOOLS=(find xargs)

brief() {
    cat <<'EOF'
tree/ is a small file tree with sizes, ages, types and a few awkward names. tree/REF is
a reference file dated 2024-02-01. Produce, with find (and xargs/sort/wc where useful):

1. big.txt      paths of regular files LARGER than 100 KiB, sorted.             (-size +100k)
2. old.txt      paths of regular files NOT newer than tree/REF (modified on or before it),
                sorted — excluding REF itself.                            (! -newer)
3. empty.txt    paths of EMPTY regular files, sorted.                             (-empty)
4. count.txt    the number of regular files under tree/ (one integer) — counted in a
                way that survives the name with a newline in it (-print0 + tr/wc -c, or
                -printf '.' | wc -c).
5. renamed/     a flat directory holding a COPY of every *.txt under tree/, copied with
                ONE xargs pipeline (-print0 | xargs -0 cp -t), names unchanged.
6. every *.key under tree/ chmod'ed to 600, with -exec … {} +  (one chmod for all of
   them, not one per file).

Why: find is a query language over the filesystem. `-print0 | xargs -0` is the only
safe way to hand its results to another command, `{} +` batches where `\;` forks per
file, and `-newer` lets a file stand in for a timestamp — no date arithmetic needed.
EOF
}

hint() {
    cat <<'EOF'
find tree -type f -size +100k | sort
find tree -type f ! -newer tree/REF ! -path tree/REF | sort
find tree -type f -empty | sort
find tree -type f -print0 | tr -cd '\0' | wc -c
find tree -name '*.txt' -type f -print0 | xargs -0 cp -t renamed
find tree -name '*.key' -exec chmod 600 {} +
EOF
}

setup() {
    mkdir -p tree/etc/keys tree/var/log tree/home/ada tree/empty-dir
    bytes tree/var/log/huge.log 204800          # 200 KiB
    bytes tree/var/log/medium.log 51200         # 50 KiB
    bytes tree/home/ada/big-photo.bin 153600    # 150 KiB
    mkfile tree/home/ada/notes.txt "ada's notes"
    mkfile tree/home/ada/todo.txt "buy milk"
    mkfile tree/etc/readme.txt "config dir"
    mkfile tree/etc/keys/server.key "KEY-ONE"
    mkfile tree/etc/keys/client.key "KEY-TWO"
    mkfile tree/etc/keys/notakey.pub "PUB"
    : > tree/var/log/empty.log
    : > tree/home/ada/.placeholder
    mkfile $'tree/home/ada/odd\nname.txt' "newline in my name"
    chmod 644 tree/etc/keys/*.key tree/etc/keys/notakey.pub    # explicit: the host umask must not leak into the fixture
    : > tree/REF
    touch -d '2024-02-01 00:00' tree/REF
    touch -d '2023-12-25 10:00' tree/etc/readme.txt tree/var/log/medium.log tree/etc/keys/server.key
    touch -d '2024-01-31 23:59' tree/home/ada/notes.txt
    touch -d '2024-02-01 00:00' tree/var/log/empty.log      # exactly REF's time: NOT newer → old
    touch -d '2024-06-01 12:00' tree/var/log/huge.log tree/home/ada/big-photo.bin tree/home/ada/todo.txt \
        tree/etc/keys/client.key tree/etc/keys/notakey.pub tree/home/ada/.placeholder $'tree/home/ada/odd\nname.txt'
}

check() {
    expect_lines big.txt $'tree/home/ada/big-photo.bin\ntree/var/log/huge.log' "big.txt (> 100 KiB; medium.log at 50 KiB is not)"
    expect_lines old.txt $'tree/etc/keys/server.key\ntree/etc/readme.txt\ntree/home/ada/notes.txt\ntree/var/log/empty.log\ntree/var/log/medium.log' \
        "old.txt (not newer than REF — empty.log shares REF's exact mtime, so it counts)"
    expect_lines empty.txt $'tree/REF\ntree/home/ada/.placeholder\ntree/var/log/empty.log' "empty.txt"
    expect_lines count.txt "13" "count.txt (13 regular files — the newline name must count once)"
    expect_dir renamed
    if [[ -d renamed ]]; then
        local got; got="$(find renamed -mindepth 1 -maxdepth 1 -type f -print0 | sort -z | tr '\0' '|')"
        expect_eq "renamed/ holds a copy of each .txt" "$got" "renamed/notes.txt|$(printf 'renamed/odd\nname.txt')|renamed/readme.txt|renamed/todo.txt|"
        [[ -f renamed/readme.txt && "$(cat renamed/readme.txt)" == "config dir" ]] && ok "renamed/readme.txt content copied" || bad "renamed/readme.txt missing or wrong content"
    fi
    expect_mode tree/etc/keys/server.key 600
    expect_mode tree/etc/keys/client.key 600
    expect_mode tree/etc/keys/notakey.pub 644
}

solve() {
    find tree -type f -size +100k | LC_ALL=C sort > big.txt
    find tree -type f ! -newer tree/REF ! -path tree/REF | LC_ALL=C sort > old.txt
    find tree -type f -empty | LC_ALL=C sort > empty.txt
    find tree -type f -print0 | tr -cd '\0' | wc -c > count.txt
    mkdir -p renamed
    find tree -name '*.txt' -type f -print0 | xargs -0 cp -t renamed
    find tree -name '*.key' -exec chmod 600 {} +
}
