# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day22 — tar
DRILL_TITLE="tar — create with -C and --exclude, list, extract one member, strip components, keep modes"
DRILL_WEEK=4
DRILL_TOOLS=(tar gzip)

brief() {
    cat <<'EOF'
site/ is a small web project with a cache/ directory and some *.log files nobody wants
in a backup. Produce:

1. site.tar.gz — a gzip'd archive of site/ whose member names start with `site/`,
   EXCLUDING every *.log file and the whole cache/ directory. Create it so it works
   from anywhere (-C to the parent, name the directory) — the checker lists it.
2. listing.txt — the archive's member list (tar -t), sorted. Expected to match exactly:
   no logs, no cache, directories included with their trailing slash.
3. restore/ — the archive extracted here with permissions preserved: restore/site/bin/
   deploy.sh must be mode 755 and restore/site/config/secret.key mode 600.
4. one-file/ — ONLY the member site/config/app.conf extracted into this directory
   (so one-file/site/config/app.conf exists and nothing else does).
5. flat/ — the archive extracted with --strip-components=1, so flat/bin/deploy.sh,
   flat/config/app.conf … exist with no `site/` prefix.

Why: tar's three flags are c/t/x, and almost everything else people fumble is -C (which
directory the names are relative to), --exclude (patterns, not paths), and -p (modes
survive only if you ask). --strip-components is how release tarballs get unpacked into
a directory you chose, not the one the packager chose.
EOF
}

hint() {
    cat <<'EOF'
tar -czf site.tar.gz --exclude='*.log' --exclude='site/cache' -C . site
tar -tzf site.tar.gz | sort
mkdir restore && tar -xpzf site.tar.gz -C restore
mkdir one-file && tar -xzf site.tar.gz -C one-file site/config/app.conf
mkdir flat && tar -xzf site.tar.gz -C flat --strip-components=1
EOF
}

setup() {
    mkdir -p site/bin site/config site/public/img site/cache/pages site/logs
    mkfile site/bin/deploy.sh '#!/bin/sh' 'echo deploy'
    mkfile site/config/app.conf 'name = site' 'port = 8080'
    mkfile site/config/secret.key 'TOP-SECRET'
    mkfile site/public/index.html '<h1>hi</h1>'
    mkfile site/public/img/logo.txt 'logo placeholder'
    mkfile site/cache/pages/index.cache 'cached'
    mkfile site/logs/access.log 'hit'
    mkfile site/logs/error.log 'oops'
    mkfile site/README.md '# site'
    chmod 755 site/bin/deploy.sh; chmod 600 site/config/secret.key
    chmod 644 site/config/app.conf site/public/index.html site/public/img/logo.txt site/README.md
}

LISTING='site/
site/README.md
site/bin/
site/bin/deploy.sh
site/config/
site/config/app.conf
site/config/secret.key
site/logs/
site/public/
site/public/img/
site/public/img/logo.txt
site/public/index.html'

check() {
    expect_file site.tar.gz
    if [[ -f site.tar.gz ]]; then
        expect_eq "members of site.tar.gz (listed by the checker)" "$(tar -tzf site.tar.gz 2>/dev/null | sort)" "$LISTING"
    fi
    expect_lines listing.txt "$LISTING" "listing.txt"
    expect_file restore/site/bin/deploy.sh
    expect_mode restore/site/bin/deploy.sh 755
    expect_mode restore/site/config/secret.key 600
    expect_no_path restore/site/cache "restore/site/cache (excluded)"
    expect_no_path restore/site/logs/access.log "restore/site/logs/access.log (excluded)"
    expect_file one-file/site/config/app.conf
    if [[ -d one-file ]]; then expect_eq "files under one-file/" "$(find one-file -type f | wc -l)" 1; fi
    expect_file flat/bin/deploy.sh "flat/bin/deploy.sh (no site/ prefix)"
    expect_file flat/config/app.conf
    expect_no_path flat/site "flat/site (the prefix must have been stripped)"
}

solve() {
    tar -czf site.tar.gz --exclude='*.log' --exclude='site/cache' -C . site
    tar -tzf site.tar.gz | LC_ALL=C sort > listing.txt
    mkdir -p restore && tar -xpzf site.tar.gz -C restore
    mkdir -p one-file && tar -xzf site.tar.gz -C one-file site/config/app.conf
    mkdir -p flat && tar -xzf site.tar.gz -C flat --strip-components=1
}
