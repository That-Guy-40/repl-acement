# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day28 — BOSS 4: Indigo Fin Whale — the vault
DRILL_TITLE="vault.sh — snapshot + manifest + verify + prune + lock, scheduled: a backup system you can trust"
DRILL_WEEK=4
DRILL_TOOLS=(rsync sha256sum flock systemd-analyze)

brief() {
    cat <<'EOF'
⚔ BOSS BATTLE 4 — the week's pieces assembled into one tool.

    vault.sh snapshot SRC VAULT NAME     rsync -a snapshot of SRC/ into VAULT/NAME/ with
                                         --link-dest=VAULT/latest (day 24); THEN write
                                         VAULT/NAME.sha256 — a manifest of the snapshot
                                         (day 25, paths relative to the snapshot); THEN
                                         verify the snapshot against its fresh manifest
                                         before pointing VAULT/latest at NAME. Exit 1
                                         (and leave `latest` alone) if verification fails.
    vault.sh verify VAULT NAME           re-verify VAULT/NAME against VAULT/NAME.sha256:
                                         silent + exit 0 when intact; otherwise print
                                         MODIFIED/MISSING/EXTRA lines and exit 1.
    vault.sh prune VAULT KEEP            delete all but the KEEP newest snapshots (newest
                                         = last in `sort` order of names) together with
                                         their manifests — never the one `latest` points to.
    vault.sh --help                      usage on stdout, exit 0; bad usage → 64.

  • snapshot takes a NON-BLOCKING lock on VAULT/.lock (flock -n); a second concurrent
    snapshot exits 75 with `already running` on stderr (day 26).
  • vault.timer + vault.service in the fixture dir: daily at midnight (OnCalendar that
    normalises to `*-*-* 00:00:00`), Type=oneshot, absolute ExecStart.

The checker: snapshots data-v1..v4 as s1..s4; checks hard-link sharing and `latest`;
tampers with s2 and expects `verify` to name the file; prunes to 2 and expects s3,s4
(and their manifests) to remain; holds the lock and expects 75; normalises the timer.

Why a boss: this is a real backup system — about 80 lines — and every property it has
is one you can now TEST rather than hope for: the copy is complete (manifest), the copy
is what it was (verify), the disk is not full of copies (link-dest + prune), two runs
cannot collide (lock), and it runs when you are asleep (timer).
EOF
}

hint() {
    cat <<'EOF'
Reuse yesterday's pieces as functions inside vault.sh: do_snapshot, do_manifest, do_verify, do_prune.
snapshot: rsync … && manifest > "$vault/$name.sha256" && verify "$vault" "$name" && ln -sfn "$name" "$vault/latest"
prune: list snapshot dirs sorted; keep=$(readlink "$vault/latest"); remove from the oldest until KEEP remain, skipping $keep.
Spell every removal with ${var:?} so an empty variable stops the script instead of widening the rm.
EOF
}

setup() {
    mkdir -p data-v1
    bytes data-v1/big.bin 32768
    mkfile data-v1/notes.txt 'v1'
    cp -a data-v1 data-v2; mkfile data-v2/notes.txt 'v2'
    cp -a data-v2 data-v3; mkfile data-v3/extra.txt 'v3'
    cp -a data-v3 data-v4; mkfile data-v4/notes.txt 'v4'
    # rsync's quick check is size+mtime and 'v1'..'v4' are the same size: unchanged files
    # keep ONE mtime across versions, each edit gets a new one.
    find data-v1 data-v2 data-v3 data-v4 -exec touch -d '2024-06-01 09:00' {} +
    touch -d '2024-06-02 09:00' data-v2/notes.txt data-v3/notes.txt
    touch -d '2024-06-03 09:00' data-v3/extra.txt data-v4/extra.txt
    touch -d '2024-06-04 09:00' data-v4/notes.txt
}

check() {
    expect_executable vault.sh
    [[ -x vault.sh ]] || return
    local rc out i v
    rm -rf vault
    for i in 1 2 3 4; do
        ( ./vault.sh snapshot "data-v$i" vault "s$i" ) >/dev/null 2>&1; rc=$?
        expect_eq "vault.sh snapshot data-v$i vault s$i exit status" "$rc" 0
    done
    for i in 1 2 3 4; do expect_file "vault/s$i.sha256"; done
    [[ -d vault/s4 ]] && expect_same_tree data-v4 vault/s4 "vault/s4 == data-v4"
    [[ -f vault/s1/big.bin ]] && expect_eq "big.bin link count across 4 snapshots" "$(stat -c %h vault/s1/big.bin)" 4
    [[ -L vault/latest ]] && expect_eq "vault/latest" "$(readlink vault/latest)" "s4" || bad "vault/latest is not a symlink"
    ( ./vault.sh verify vault s2 ) >/dev/null 2>&1; rc=$?; expect_eq "verify s2 (intact) exits 0" "$rc" 0
    if [[ -f vault/s2/notes.txt ]]; then
        # tamper s2 WITHOUT touching the hard-linked big.bin: notes.txt's bytes are unique to s2
        printf 'tampered\n' > vault/s2/notes.txt
        out="$(./vault.sh verify vault s2 2>/dev/null)"; ( ./vault.sh verify vault s2 ) >/dev/null 2>&1; rc=$?
        expect_eq "verify s2 (tampered) exits 1" "$rc" 1
        expect_match "verify s2 names the modified file" "$out" 'MODIFIED notes.txt'
    fi
    ( ./vault.sh prune vault 2 ) >/dev/null 2>&1; rc=$?
    expect_eq "prune vault 2 exit status" "$rc" 0
    expect_no_path vault/s1 "vault/s1 (pruned)"; expect_no_path vault/s2 "vault/s2 (pruned)"
    expect_no_path vault/s1.sha256 "vault/s1.sha256 (pruned with its snapshot)"
    expect_dir vault/s3; expect_dir vault/s4; expect_file vault/s4.sha256
    [[ -L vault/latest && "$(readlink vault/latest)" == s4 ]] && ok "latest still → s4 after prune" || bad "prune broke or removed latest"
    mkdir -p vault
    flock vault/.lock sleep 2 &
    local holder=$!; sleep 0.3
    out="$(./vault.sh snapshot data-v1 vault s9 2>&1 >/dev/null)"; ( ./vault.sh snapshot data-v1 vault s9 ) >/dev/null 2>&1; rc=$?
    expect_eq "snapshot while locked exits 75" "$rc" 75
    expect_match "snapshot while locked says so on stderr" "$out" 'already running'
    kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
    expect_no_path vault/s9 "vault/s9 (the locked-out snapshot must not have been created)"
    out="$(./vault.sh --help 2>/dev/null)"; ./vault.sh --help >/dev/null 2>&1; rc=$?
    [[ -n "$out" && $rc -eq 0 ]] && ok "--help on stdout, exit 0" || bad "--help should print usage to stdout and exit 0"
    ./vault.sh bogus >/dev/null 2>&1; rc=$?; expect_eq "unknown subcommand exits 64" "$rc" 64
    ./vault.sh snapshot onlyone >/dev/null 2>&1; rc=$?; expect_eq "snapshot with too few args exits 64" "$rc" 64
    expect_file vault.timer; expect_file vault.service
    if [[ -f vault.timer ]]; then
        v="$(sed -n 's/^OnCalendar=//p' vault.timer | head -1)"
        if [[ -z "$v" ]]; then bad "vault.timer has no OnCalendar="
        elif have systemd-analyze; then
            expect_eq "OnCalendar '$v' normalises to" "$(systemd-analyze calendar "$v" 2>/dev/null | sed -n 's/^ *Normalized form: *//p')" "*-*-* 00:00:00"
        else unknown "systemd-analyze missing: OnCalendar='$v' not normalised"; fi
    fi
    [[ -f vault.service ]] && { expect_grep vault.service '^Type=oneshot$' "vault.service Type=oneshot"; expect_grep vault.service '^ExecStart=/' "vault.service absolute ExecStart"; }
}

solve() {
    cat > vault.sh <<'EOF'
#!/usr/bin/env bash
# vault.sh — snapshot | verify | prune : an rsync --link-dest vault with sha256 manifests and a lock
set -uo pipefail
usage() {
    cat <<'USAGE'
usage: vault.sh snapshot SRC VAULT NAME | verify VAULT NAME | prune VAULT KEEP | --help
USAGE
}
die_usage() { printf 'vault.sh: %s\n' "$*" >&2; usage >&2; exit 64; }

do_manifest() {                      # do_manifest DIR → manifest on stdout
    ( cd -- "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sed 's#^\([0-9a-f]*\)  \./#\1  #' )
}
do_verify() {                        # do_verify DIR MANIFEST → problems on stdout; status 1 if any
    local dir=$1 manifest; manifest=$(readlink -f -- "$2") || return 1
    local problems
    problems=$(
        cd -- "$dir" || exit 1
        sha256sum -c --quiet -- "$manifest" 2>/dev/null \
            | sed -n -e 's/^\(.*\): FAILED open or read$/MISSING \1/p' -e 's/^\(.*\): FAILED$/MODIFIED \1/p'
        comm -13 <(awk '{ $1=""; sub(/^ +/, ""); print }' "$manifest" | LC_ALL=C sort) \
                 <(find . -type f | sed 's#^\./##' | LC_ALL=C sort) | sed 's/^/EXTRA /'
    )
    [[ -z $problems ]] && return 0
    printf '%s\n' "$problems" | LC_ALL=C sort
    return 1
}
cmd_snapshot() {
    local src=$1 vault=$2 name=$3
    [[ -d $src ]] || { printf 'vault.sh: no such source: %s\n' "$src" >&2; exit 1; }
    mkdir -p -- "$vault"
    exec 9> "$vault/.lock"
    flock -n 9 || { echo 'already running' >&2; exit 75; }
    local link=()
    [[ -e $vault/latest ]] && link=(--link-dest="$(cd -- "$vault" && pwd)/latest")
    rsync -a "${link[@]}" -- "$src/" "$vault/$name/" || exit 1
    do_manifest "$vault/$name" > "$vault/$name.sha256"
    if ! do_verify "$vault/$name" "$vault/$name.sha256"; then
        printf 'vault.sh: snapshot %s failed verification; latest left unchanged\n' "$name" >&2
        exit 1
    fi
    ln -sfn -- "$name" "$vault/latest"
}
cmd_verify() { do_verify "$1/$2" "$1/$2.sha256"; }
cmd_prune() {
    local vault=$1 keep=$2 latest="" s n
    [[ $keep =~ ^[0-9]+$ ]] || die_usage "KEEP must be a number"
    [[ -L $vault/latest ]] && latest=$(readlink -- "$vault/latest")
    mapfile -t snaps < <(cd -- "$vault" && find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)
    n=${#snaps[@]}
    for s in "${snaps[@]}"; do
        (( n <= keep )) && break
        [[ $s == "$latest" ]] && continue
        # ${var:?} on BOTH parts: an empty $vault or $s aborts here instead of widening the rm
        rm -rf -- "${vault:?}/${s:?}" "${vault:?}/${s:?}.sha256"
        n=$((n - 1))
    done
}
case ${1-} in
    --help|-h|help) usage; exit 0 ;;
    snapshot) (( $# == 4 )) || die_usage "snapshot needs SRC VAULT NAME"; cmd_snapshot "$2" "$3" "$4" ;;
    verify)   (( $# == 3 )) || die_usage "verify needs VAULT NAME";       cmd_verify "$2" "$3" ;;
    prune)    (( $# == 3 )) || die_usage "prune needs VAULT KEEP";        cmd_prune "$2" "$3" ;;
    *) die_usage "unknown subcommand '${1-}'" ;;
esac
EOF
    chmod +x vault.sh
    cat > vault.timer <<'EOF'
[Unit]
Description=Daily vault snapshot

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    cat > vault.service <<'EOF'
[Unit]
Description=Vault snapshot

[Service]
Type=oneshot
ExecStart=/home/learner/bin/vault.sh snapshot /home/learner/data /home/learner/vault daily
EOF
}
