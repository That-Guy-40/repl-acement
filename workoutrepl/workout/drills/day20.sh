# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day20 — Permissions and links
DRILL_TITLE="Permissions and links — symbolic chmod, umask, setgid directories, hard versus soft links"
DRILL_WEEK=3
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
1. make-team.sh — creates team/ as a shared project directory:
     team/            mode 2770  (rwxrws---: setgid, so new files inherit the group)
     team/README      mode 640
     team/run.sh      mode 750   (and it must actually be runnable: put `#!/bin/sh` +
                                  `echo ok` in it)
     team/private/    mode 700
   Use SYMBOLIC modes at least once (u=rwx,g=rwxs,o= …) — the checker only sees the
   result, but write them that way and see how they read.

2. umask.sh — prints two lines: the permission string (as `stat -c %A`) of a file
   created under umask 077, then of one created under umask 022 — created by the
   script itself in tmp/ (which it may create), e.g.
       -rw-------
       -rw-r--r--

3. links/ — data.txt containing `original`, a HARD link data.hard to it and a SYMBOLIC
   link data.sym to it (relative target `data.txt`). Then append the line `appended`
   to data.hard. The checker asserts: data.txt has link count 2, data.sym → data.txt,
   and all three read `original\nappended`.

4. answers.txt — one line: why is `chmod -R 644 project/` a mistake?
   (The checker looks for the idea: directories need the x bit to be entered/searched.)

Why: modes are a tiny language (who / what / which bits), umask is the subtraction
everyone forgets exists, setgid on a directory is how teams share without chown, and a
hard link is the same inode wearing two names — which is also how snapshots work.
EOF
}

hint() {
    cat <<'EOF'
mkdir -p team/private; chmod u=rwx,g=rwxs,o= team; chmod 640 team/README; chmod 750 team/run.sh; chmod 700 team/private
( umask 077; : > tmp/a ); stat -c %A tmp/a
ln links/data.txt links/data.hard; ln -s data.txt links/data.sym; stat -c %h links/data.txt
A directory's x bit means "may traverse" — 644 on a directory locks everyone, including you, out.
EOF
}

setup() { mkfile notes.txt "Q: why is 'chmod -R 644 project/' a mistake?"; }

check() {
    local out
    expect_executable make-team.sh
    if [[ -x make-team.sh ]]; then
        rm -rf team; ( ./make-team.sh ) >/dev/null 2>&1
        expect_mode team 2770
        expect_mode team/README 640
        expect_mode team/run.sh 750
        expect_mode team/private 700
        out="$(team/run.sh 2>/dev/null)"; expect_eq "team/run.sh runs and prints ok" "$out" "ok"
    fi
    expect_executable umask.sh
    if [[ -x umask.sh ]]; then
        out="$(./umask.sh 2>/dev/null)"
        expect_eq "umask.sh" "$out" $'-rw-------\n-rw-r--r--'
    fi
    expect_dir links
    if [[ -d links ]]; then
        expect_eq "links/data.txt link count" "$(stat -c %h links/data.txt 2>/dev/null)" 2
        [[ -L links/data.sym ]] && expect_eq "links/data.sym target" "$(readlink links/data.sym)" "data.txt" || bad "links/data.sym is not a symbolic link"
        [[ ! -L links/data.hard && -f links/data.hard ]] && ok "links/data.hard is a hard link (a regular file, not a symlink)" || bad "links/data.hard should be a hard link — a plain file sharing the inode"
        [[ "$(stat -c %i links/data.txt 2>/dev/null)" == "$(stat -c %i links/data.hard 2>/dev/null)" ]] && ok "data.txt and data.hard share one inode" || bad "data.txt and data.hard have different inodes"
        expect_content links/data.txt $'original\nappended\n' "links/data.txt (sees the append made through data.hard)"
        expect_content links/data.sym $'original\nappended\n' "links/data.sym (follows to the same bytes)"
    fi
    if [[ -f answers.txt ]]; then
        expect_match "answer mentions the directory execute/search bit" "$(tr 'A-Z' 'a-z' < answers.txt | tr '\n' ' ')" '(director|folder).*(x|exec|search|travers|enter|cd)|(x|exec|search|travers|enter).*(director|folder)'
    else bad "answers.txt is missing"; fi
}

solve() {
    cat > make-team.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p team/private
printf '%s\n' '#!/bin/sh' 'echo ok' > team/run.sh
printf 'team project\n' > team/README
chmod u=rwx,g=rwxs,o= team          # 2770: setgid so new files take the group
chmod u=rw,g=r,o= team/README       # 640
chmod u=rwx,g=rx,o= team/run.sh     # 750
chmod u=rwx,go= team/private        # 700
EOF
    cat > umask.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p tmp
( umask 077; : > tmp/strict )       # umask is per-process: change it in a subshell
( umask 022; : > tmp/shared )
stat -c %A tmp/strict
stat -c %A tmp/shared
EOF
    chmod +x make-team.sh umask.sh
    ./make-team.sh
    mkdir -p links
    printf 'original\n' > links/data.txt
    ln links/data.txt links/data.hard
    ln -s data.txt links/data.sym
    printf 'appended\n' >> links/data.hard
    printf '%s\n' 'Directories need the x (search) bit to be entered; 644 on a directory makes it untraversable — use chmod -R a+X or separate file and directory modes.' > answers.txt
}
