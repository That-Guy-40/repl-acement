# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day09 — sed
DRILL_TITLE="sed — in-place with a backup, addresses, -n/p, groups and backreferences"
DRILL_WEEK=2
DRILL_TOOLS=(sed)

brief() {
    cat <<'EOF'
Four edits, all with sed (one invocation each is possible; several are fine):

1. app.conf — edit IN PLACE keeping a backup named app.conf.bak (sed -i.bak):
     • `debug = false`  →  `debug = true`
     • the commented-out `;port = 8080` → an active `port = 9090`
     • delete every comment line (starting with # or ;) whose text contains `deprecated`
     • insert the line `max_conn = 100` immediately AFTER the `[server]` header
   Nothing else in the file may change (the checker diffs against the exact result).

2. hosts-swapped.txt — hosts.txt has `ip<TAB>hostname` lines (and a comment header to
   keep as-is); write the data lines with the two columns swapped, still tab-separated.
   Use a group and a backreference, not cut/awk.

3. names.txt — lines 3 to 5 of hosts.txt (inclusive), and nothing else.        (-n '3,5p')

4. versions.txt — releases.txt has one free-text line per release; print ONLY the
   version token (like v1.2.3) from each line that has one, one per line, in order.
   Lines without a version print nothing.                           (-n 's/.../\1/p')

Why: sed is the stream editor — a filter that reads once and never loads the file.
The fluent idioms are small: an address (line, range, /regex/), a command (s d i a p),
and -n with p to make sed print only what you ask for.
EOF
}

hint() {
    cat <<'EOF'
sed -i.bak -e 's/^debug = false$/debug = true/' -e 's/^;port = 8080$/port = 9090/' \
    -e '/^[#;].*deprecated/d' -e '/^\[server\]$/a max_conn = 100' app.conf
sed -E 's/^([^\t#]+)\t(.+)$/\2\t\1/' hosts.txt          # groups swap columns
sed -nE 's/.*\b(v[0-9]+\.[0-9]+\.[0-9]+)\b.*/\1/p' releases.txt
EOF
}

setup() {
    cat > app.conf <<'EOF'
# application settings
[server]
host = 0.0.0.0
;port = 8080
# the old listen key is deprecated, use port
workers = 4

[logging]
debug = false
; verbose is deprecated since 2.0
level = info
EOF
    printf '# ip\thostname\n' > hosts.txt
    printf '%s\t%s\n' 10.0.0.1 gateway 10.0.0.5 web-1 10.0.0.6 web-2 10.0.0.9 db-1 10.0.0.20 backup >> hosts.txt
    mkfile releases.txt "Released v1.2.3 to production on Monday" "hotfix for the login page" \
        "v2.0.0 shipped with the new parser" "docs refresh (no version bump)" "tagged v2.0.1 after the regression"
}

APP_WANT='# application settings
[server]
max_conn = 100
host = 0.0.0.0
port = 9090
workers = 4

[logging]
debug = true
level = info'

check() {
    expect_content app.conf "$APP_WANT"$'\n' "app.conf (edited in place)"
    if [[ -f app.conf.bak ]]; then
        if grep -q '^debug = false$' app.conf.bak && grep -q '^;port = 8080$' app.conf.bak; then ok "app.conf.bak holds the original"
        else bad "app.conf.bak exists but is not the original file"; fi
    else bad "app.conf.bak is missing (sed -i.bak keeps the original)"; fi
    expect_lines hosts-swapped.txt "$(printf '# ip\thostname\n'; printf '%s\t%s\n' gateway 10.0.0.1 web-1 10.0.0.5 web-2 10.0.0.6 db-1 10.0.0.9 backup 10.0.0.20)" \
        "hosts-swapped.txt (columns swapped, header kept)"
    expect_lines names.txt "$(printf '%s\t%s\n' 10.0.0.5 web-1 10.0.0.6 web-2 10.0.0.9 db-1)" "names.txt (lines 3-5)"
    expect_lines versions.txt $'v1.2.3\nv2.0.0\nv2.0.1' "versions.txt (version tokens only)"
}

solve() {
    sed -i.bak -e 's/^debug = false$/debug = true/' \
               -e 's/^;port = 8080$/port = 9090/' \
               -e '/^[#;].*deprecated/d' \
               -e '/^\[server\]$/a max_conn = 100' app.conf
    sed -E 's/^([^\t#]+)\t(.+)$/\2\t\1/' hosts.txt > hosts-swapped.txt
    sed -n '3,5p' hosts.txt > names.txt
    sed -nE 's/.*\b(v[0-9]+\.[0-9]+\.[0-9]+)\b.*/\1/p' releases.txt > versions.txt
}
