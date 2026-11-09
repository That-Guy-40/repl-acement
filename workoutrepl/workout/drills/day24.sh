# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day24 — rsync snapshots with --link-dest
DRILL_TITLE="snapshot.sh — rsync --link-dest incremental snapshots that share unchanged files by hard link"
DRILL_WEEK=4
DRILL_TOOLS=(rsync)

brief() {
    cat <<'EOF'
data-v1/, data-v2/, data-v3/ are three states of the same directory: v2 changes one
file (notes.txt), v3 adds one (extra.txt) and changes nothing else.

Write snapshot.sh SRC DEST NAME:
  • creates DEST/NAME/ as an rsync -a copy of SRC/, using  --link-dest=DEST/latest
    when DEST/latest exists (so unchanged files are HARD-LINKED to the previous
    snapshot and cost no space);
  • then points the symlink DEST/latest at NAME (a RELATIVE symlink: `latest -> NAME`),
    replacing any previous one atomically (ln -sfn, or ln -s to a temp name + mv -T).

Run it three times:  ./snapshot.sh data-v1 vault snap1 ; data-v2 → snap2 ; data-v3 → snap3.

The checker asserts, with stat: big.bin (unchanged throughout) has link count 3 and
the same inode in all three snapshots; notes.txt in snap1 and snap2 have DIFFERENT
inodes (it changed) while snap2's and snap3's are the SAME (it did not); extra.txt
exists only in snap3; and vault/latest → snap3.

Why: this is Time Machine / rsnapshot / Borg's ancestor in one flag. Every snapshot is
a complete, browsable tree, yet N snapshots of a stable dataset cost ~1× the data.
It works because a hard link is just another name for an inode (day 20).
EOF
}

hint() {
    cat <<'EOF'
link=(); [[ -e "$dest/latest" ]] && link=(--link-dest="$(cd "$dest" && pwd)/latest")
rsync -a "${link[@]}" "$src/" "$dest/$name/"
ln -sfn "$name" "$dest/latest"           # -n: do not descend into the OLD latest
--link-dest paths are relative to the DESTINATION directory unless absolute — use an absolute one.
EOF
}

setup() {
    mkdir -p data-v1
    bytes data-v1/big.bin 65536
    mkfile data-v1/notes.txt 'first'
    mkfile data-v1/config.ini '[a]' 'b=1'
    cp -a data-v1 data-v2; mkfile data-v2/notes.txt 'second'
    cp -a data-v2 data-v3; mkfile data-v3/extra.txt 'new in v3'
    # rsync's quick check is size+mtime, so UNCHANGED files must carry the SAME mtime in
    # every version (or --link-dest will copy instead of link) and changed ones a new one.
    find data-v1 data-v2 data-v3 -exec touch -d '2024-06-01 09:00' {} +
    touch -d '2024-06-02 09:00' data-v2/notes.txt data-v3/notes.txt     # changed in v2, same in v3
    touch -d '2024-06-03 09:00' data-v3/extra.txt
}

check() {
    expect_executable snapshot.sh
    local d
    for d in snap1 snap2 snap3; do expect_dir "vault/$d"; done
    [[ -d vault/snap1 && -d vault/snap2 && -d vault/snap3 ]] || return
    expect_same_tree data-v1 vault/snap1 "vault/snap1 == data-v1"
    expect_same_tree data-v2 vault/snap2 "vault/snap2 == data-v2"
    expect_same_tree data-v3 vault/snap3 "vault/snap3 == data-v3"
    expect_eq "big.bin link count (shared by three snapshots)" "$(stat -c %h vault/snap1/big.bin 2>/dev/null)" 3
    [[ "$(stat -c %i vault/snap1/big.bin)" == "$(stat -c %i vault/snap3/big.bin)" ]] && ok "big.bin is one inode across snap1 and snap3" || bad "big.bin was copied, not hard-linked, between snapshots (different inodes)"
    [[ "$(stat -c %i vault/snap1/notes.txt)" != "$(stat -c %i vault/snap2/notes.txt)" ]] && ok "notes.txt changed in v2, so snap1 and snap2 hold different inodes" || bad "notes.txt in snap1 and snap2 share an inode — but the content changed, so snap1 has been corrupted"
    [[ "$(stat -c %i vault/snap2/notes.txt)" == "$(stat -c %i vault/snap3/notes.txt)" ]] && ok "notes.txt unchanged in v3, so snap2 and snap3 share it" || bad "notes.txt in snap2 and snap3 do not share an inode although it did not change"
    expect_no_path vault/snap2/extra.txt "vault/snap2/extra.txt (only exists from v3)"
    [[ -L vault/latest ]] && expect_eq "vault/latest symlink target" "$(readlink vault/latest)" "snap3" || bad "vault/latest is not a symlink"
}

solve() {
    cat > snapshot.sh <<'EOF'
#!/usr/bin/env bash
# snapshot.sh SRC DEST NAME — an rsync snapshot hard-linked against DEST/latest
set -euo pipefail
src=${1:?SRC} dest=${2:?DEST} name=${3:?NAME}
mkdir -p -- "$dest"
link=()
# --link-dest is resolved relative to the DESTINATION, so hand it an absolute path.
[[ -e $dest/latest ]] && link=(--link-dest="$(cd -- "$dest" && pwd)/latest")
rsync -a "${link[@]}" -- "$src/" "$dest/$name/"
ln -sfn -- "$name" "$dest/latest"      # -n: replace the link, do not write INTO the old target
EOF
    chmod +x snapshot.sh
    ./snapshot.sh data-v1 vault snap1
    ./snapshot.sh data-v2 vault snap2
    ./snapshot.sh data-v3 vault snap3
}
