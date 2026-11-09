# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day29 — Review with shellcheck
DRILL_TITLE="shellcheck — fix a legacy script's findings without changing what it does (except where it was wrong)"
DRILL_WEEK=5
DRILL_TOOLS=(shellcheck)

brief() {
    cat <<'EOF'
legacy.sh (provided) counts the files in a directory, lists the ones larger than a
threshold, and prints a summary. It "works" on the author's machine. shellcheck finds
several things wrong with it, and one of them is a real bug: on the fixture (which has
a filename with a space) it reports the wrong count.

1. Run  shellcheck legacy.sh  and read every finding. Each has a wiki page
   (https://www.shellcheck.net/wiki/SC2086 etc.) — read the ones you do not know.
2. Fix legacy.sh until  shellcheck -S warning legacy.sh  is CLEAN (no output, exit 0).
   Do not suppress findings with `# shellcheck disable` — fix them.
3. Keep the behaviour: on the fixture,  ./legacy.sh sample 100  must print exactly
   expected-output.txt (which is what a CORRECT program prints — the original does not).

Why: shellcheck is the cheapest code review you will ever get, and its findings are a
curriculum: SC2086 (quote it), SC2046 (quote the substitution), SC2006 (backticks),
SC2045 (don't iterate `ls`), SC2164 (cd can fail), SC2155 (declare and assign
separately), SC2002 (useless cat), SC2162 (read -r). Fluent people have internalised
every one of them and still run the tool, because it is not about knowing — it is
about the one you missed.
EOF
}

hint() {
    cat <<'EOF'
for f in "$dir"/*          # not  for f in $(ls $dir)
size=$(stat -c %s -- "$f") # not  `stat -c %s $f`
cd "$dir" || exit 1        # SC2164
local n; n=$(…)            # SC2155: declare, then assign
while read -r line         # SC2162
EOF
}

setup() {
    mkdir -p sample
    bytes sample/big.dat 300
    bytes sample/small.txt 50
    bytes "sample/with space.log" 200
    bytes sample/tiny 10
    cat > legacy.sh <<'EOF'
#!/bin/bash
# legacy.sh DIR THRESHOLD — count files, list the big ones, summarise
dir=$1
threshold=$2
count=0
big=0
cd $dir
for f in $(ls); do
    count=`expr $count + 1`
    size=`stat -c %s $f`
    if [ $size -gt $threshold ]; then
        echo "big: $f ($size bytes)"
        big=`expr $big + 1`
    fi
done
cat ../expected-output.txt > /dev/null
echo "files: $count"
echo "big: $big"
EOF
    chmod +x legacy.sh
    # what a CORRECT program prints: 4 files (the spaced name is ONE file), 2 big ones
    cat > expected-output.txt <<'EOF'
big: big.dat (300 bytes)
big: with space.log (200 bytes)
files: 4
big: 2
EOF
}

check() {
    expect_executable legacy.sh
    [[ -x legacy.sh ]] || return
    local out rc
    if have shellcheck; then
        out="$(shellcheck -S warning legacy.sh 2>&1)"; rc=$?
        if (( rc == 0 )); then ok "shellcheck -S warning legacy.sh is clean"
        else bad "shellcheck still reports: $(grep -oE 'SC[0-9]+' <<<"$out" | sort -u | tr '\n' ' ')"; fi
        grep -q 'shellcheck disable' legacy.sh && bad "legacy.sh suppresses a finding with 'shellcheck disable' — fix it instead" || ok "no findings were suppressed"
    else
        unknown "shellcheck is not installed, so the script was not linted"
    fi
    out="$(./legacy.sh sample 100 2>&1 | sort)"
    expect_eq "./legacy.sh sample 100 (sorted) == expected-output.txt" "$out" "$(sort expected-output.txt)"
}

solve() {
    cat > legacy.sh <<'EOF'
#!/bin/bash
# legacy.sh DIR THRESHOLD — count files, list the big ones, summarise
set -u
dir=${1:?usage: legacy.sh DIR THRESHOLD}
threshold=${2:?usage: legacy.sh DIR THRESHOLD}
count=0
big=0
cd "$dir" || exit 1
for f in *; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    size=$(stat -c %s -- "$f")
    if [ "$size" -gt "$threshold" ]; then
        echo "big: $f ($size bytes)"
        big=$((big + 1))
    fi
done
echo "files: $count"
echo "big: $big"
EOF
    chmod +x legacy.sh
}
