# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day25 — Checksums and verification
DRILL_TITLE="manifest.sh / verify.sh — sha256 manifests that catch MODIFIED, MISSING and EXTRA files"
DRILL_WEEK=4
DRILL_TOOLS=(sha256sum)

brief() {
    cat <<'EOF'
A backup you have not verified is a hope. Two scripts:

1. manifest.sh DIR — prints a sha256sum manifest of every regular file under DIR, with
   paths RELATIVE to DIR (so the manifest is portable), sorted by path:
       <sha256>  <relative/path>
   (two spaces, sha256sum's own format, so `sha256sum -c` can read it).

2. verify.sh DIR MANIFEST — compares DIR against MANIFEST and prints, sorted, one line
   per problem:
       MODIFIED <path>     content differs
       MISSING  <path>     in the manifest, not on disk
       EXTRA    <path>     on disk, not in the manifest
   Exit 0 and print nothing when everything matches; exit 1 otherwise. `sha256sum -c`
   finds the first two kinds; EXTRA files it cannot see — that is the part you write.

The fixture is tree/ plus three copies of it the checker will mutate: one byte flipped
in a file, one file deleted, one file added. A manifest of tree/ is what you verify
them against.

Why: a digest computed when the backup is WRITTEN and checked when it is READ is the
only thing that turns "the copy succeeded" into "the copy is what I think it is".
Derive the fact from the bytes; a cached record that outlives its subject is how a
restore fails at the worst possible moment.
EOF
}

hint() {
    cat <<'EOF'
( cd "$dir" && find . -type f -print0 | sort -z | xargs -0 sha256sum ) | sed 's#  \./#  #'
( cd "$dir" && sha256sum -c --quiet "$abs_manifest" 2>&1 ) | sed -n 's/: FAILED open or read$/ MISSING/p; s/: FAILED$/ MODIFIED/p'
comm -13 <(awk '{print $2}' manifest | sort) <(cd "$dir" && find . -type f | sed 's#^\./##' | sort)   # EXTRA
EOF
}

setup() {
    mkdir -p tree/a tree/b/c
    mkfile tree/a/one.txt 'one'
    mkfile tree/a/two.txt 'two'
    mkfile tree/b/three.txt 'three'
    mkfile tree/b/c/four.txt 'four'
    mkfile tree/top.txt 'top'
}

check() {
    expect_executable manifest.sh
    expect_executable verify.sh
    [[ -x manifest.sh && -x verify.sh ]] || return
    local m out rc
    m="$PWD/.manifest"
    ./manifest.sh tree > "$m" 2>/dev/null
    expect_eq "manifest.sh: paths and order" "$(awk '{print $2}' "$m" | tr '\n' ' ')" "a/one.txt a/two.txt b/c/four.txt b/three.txt top.txt "
    expect_eq "manifest.sh: digest of a/one.txt" "$(awk '$2=="a/one.txt"{print $1}' "$m")" "$(sha256sum tree/a/one.txt | cut -d' ' -f1)"
    grep -q '^[0-9a-f]\{64\}  [^ ]' "$m" && ok "manifest.sh: sha256sum format (two spaces, no ./ prefix)" || bad "manifest.sh output is not in 'sha256  path' format or has a ./ prefix"
    out="$(./verify.sh tree "$m" 2>&1)"; rc=$?
    expect_eq "verify.sh on the untouched tree exits 0" "$rc" 0
    expect_eq "verify.sh on the untouched tree prints nothing" "$out" ""
    rm -rf .mut; cp -a tree .mut
    printf 'X' | dd of=.mut/b/three.txt bs=1 seek=1 conv=notrunc 2>/dev/null
    rm -f .mut/a/two.txt
    mkfile .mut/b/c/sneaky.txt 'extra'
    out="$(./verify.sh .mut "$m" 2>/dev/null | sort)"; ./verify.sh .mut "$m" >/dev/null 2>&1; rc=$?
    expect_eq "verify.sh on the mutated copy exits 1" "$rc" 1
    expect_eq "verify.sh names all three problems" "$(sed -E 's/[[:space:]]+/ /g' <<<"$out")" $'EXTRA b/c/sneaky.txt\nMISSING a/two.txt\nMODIFIED b/three.txt'
    rm -rf .mut "$m"
}

solve() {
    cat > manifest.sh <<'EOF'
#!/usr/bin/env bash
# manifest.sh DIR — sha256 of every regular file, paths relative to DIR, sorted
set -euo pipefail
dir=${1:?usage: manifest.sh DIR}
cd -- "$dir"
find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sed 's#^\([0-9a-f]*\)  \./#\1  #'
EOF
    cat > verify.sh <<'EOF'
#!/usr/bin/env bash
# verify.sh DIR MANIFEST — MODIFIED / MISSING / EXTRA, exit 1 on any
set -uo pipefail
dir=${1:?usage: verify.sh DIR MANIFEST} manifest=${2:?MANIFEST}
manifest=$(readlink -f -- "$manifest")
problems=$(
    cd -- "$dir" || exit 1
    # sha256sum -c reports modified and missing (as "FAILED open or read")
    sha256sum -c --quiet -- "$manifest" 2>/dev/null \
        | sed -n -e 's/^\(.*\): FAILED open or read$/MISSING \1/p' -e 's/^\(.*\): FAILED$/MODIFIED \1/p'
    # extra = on disk but not in the manifest
    comm -13 <(awk '{ $1=""; sub(/^ +/, ""); print }' "$manifest" | LC_ALL=C sort) \
             <(find . -type f | sed 's#^\./##' | LC_ALL=C sort) | sed 's/^/EXTRA /'
)
[[ -z $problems ]] && exit 0
printf '%s\n' "$problems" | LC_ALL=C sort
exit 1
EOF
    chmod +x manifest.sh verify.sh
}
