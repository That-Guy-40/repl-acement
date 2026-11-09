# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day03 — Quoting and word splitting
DRILL_TITLE="Quoting and word splitting — filenames are not words"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
messy/ holds eleven files whose names contain a space, a tab, a NEWLINE, a leading
double dash, a literal $HOME, a *, a [1], and one that starts with a dot. Each file's
content is its own original name, so nothing can be lost silently.

1. Write lower.sh — `./lower.sh DIR` renames every regular file directly inside DIR
   to the lower-case version of its name (directories untouched, dot-files included).
   It must handle all eleven names, must not lose or duplicate any file, and must not
   touch a file whose name is already lower-case.

2. Run it on messy/ :  ./lower.sh messy

The checker runs YOUR script against a fresh copy of the same eleven files too, so a
hand-renamed messy/ alone will not pass.

Why: `for f in $(ls)` and `rm $file` work until the first space, and most people's
scripts are one filename away from a disaster. The fixes are small and permanent:
"$var" everywhere, `--` before names that might start with `-`, `${f,,}` for case,
and either a glob with dotglob or `find -print0 | while IFS= read -r -d ''`.
EOF
}

hint() {
    cat <<'EOF'
shopt -s dotglob nullglob
for f in "$dir"/*; do
    [[ -f "$f" ]] || continue
    base=${f##*/}; new=${base,,}
    [[ "$base" == "$new" ]] && continue
    mv -n -- "$f" "$dir/$new"
done
(`${var,,}` lower-cases in bash 4+; `mv -n` refuses to clobber; `--` ends the options.)
EOF
}

# The eleven names. Content = the original name, so a lost or clobbered file is detectable.
_messy_names() {
    printf '%s\0' 'Hello World.txt' $'Tab\tSep.TXT' $'New\nLine.Log' '--Dash-First.txt' \
        '$HOME Sweet.txt' '*Star*.TXT' 'Glob[1].TXT' '.Hidden.TXT' 'ALLCAPS' 'already.lower' 'Mixed Case Dir'
}
make_messy() {
    local d="$1" n; mkdir -p -- "$d"
    while IFS= read -r -d '' n; do
        if [[ "$n" == 'Mixed Case Dir' ]]; then mkdir -p -- "$d/$n"; else printf '%s' "$n" > "$d/$n"; fi
    done < <(_messy_names)
}
setup() { make_messy messy; }

_expect_lowered() {   # _expect_lowered <dir> <label>
    local d="$1" label="$2" n want count
    while IFS= read -r -d '' n; do
        [[ "$n" == 'Mixed Case Dir' ]] && continue
        want="${n,,}"
        if [[ -f "$d/$want" ]]; then
            if [[ "$(cat "$d/$want")" == "$n" ]]; then ok "$label: $(printf '%q' "$n") → $(printf '%q' "$want"), content intact"
            else bad "$label: $(printf '%q' "$want") exists but holds the wrong content — a different file was renamed over it"; fi
        else
            bad "$label: expected $(printf '%q' "$want") after lower-casing $(printf '%q' "$n"), not found"
        fi
    done < <(_messy_names)
    [[ -d "$d/Mixed Case Dir" ]] && ok "$label: the directory was left alone" || bad "$label: 'Mixed Case Dir' (a directory) was renamed or removed — only files"
    # Not `| wc -l`: one of the names CONTAINS a newline, so counting lines would say 11.
    count="$(find "$d" -mindepth 1 -maxdepth 1 -type f -print0 | tr -cd '\0' | wc -c)"
    expect_eq "$label: number of files" "$count" "10"
}
check() {
    expect_executable lower.sh
    _expect_lowered messy "messy/ (your run)"
    if [[ -x lower.sh ]]; then
        local fresh="$PWD/.check-fresh"; rm -rf -- "$fresh"; make_messy "$fresh"
        if ( ./lower.sh "$fresh" ) >/dev/null 2>&1; then ok "lower.sh ran cleanly on a fresh copy"; else bad "lower.sh exited non-zero on a fresh copy of the fixture"; fi
        _expect_lowered "$fresh" "fresh copy (the checker's run of your lower.sh)"
        rm -rf -- "$fresh"
    fi
}

solve() {
    cat > lower.sh <<'EOF'
#!/usr/bin/env bash
# lower.sh DIR — lower-case the names of the regular files directly inside DIR
set -euo pipefail
dir=${1:?usage: lower.sh DIR}
shopt -s dotglob nullglob
for f in "$dir"/*; do
    [[ -f "$f" ]] || continue
    base=${f##*/}
    new=${base,,}
    [[ "$base" == "$new" ]] && continue
    mv -n -- "$f" "$dir/$new"
done
EOF
    chmod +x lower.sh
    ./lower.sh messy
}
