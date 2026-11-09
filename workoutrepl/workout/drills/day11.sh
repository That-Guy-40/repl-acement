# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day11 — sort, uniq, cut, paste, join, comm, tr
DRILL_TITLE="sort/uniq/cut/paste/join/comm/tr — the relational toolkit on tab-separated text"
DRILL_WEEK=2
DRILL_TOOLS=(join comm)

brief() {
    cat <<'EOF'
users.tsv is `id<TAB>name`, logins.tsv is `id<TAB>count` (neither is sorted, and they do
not cover the same ids). old-users.txt / new-users.txt are plain name lists. Produce:

1. joined.tsv    `name<TAB>count` for every id present in BOTH files, sorted by name.
                 join needs both inputs sorted on the join field — in the SAME collation
                 (export LC_ALL=C; sort -k1,1). Use -t for the tab.
2. top3.txt      the three names with the highest count from joined.tsv, highest first,
                 `name count` separated by a single space.
3. removed.txt   names in old-users.txt but not new-users.txt, sorted.   (comm -23)
4. added.txt     names in new-users.txt but not old-users.txt, sorted.   (comm -13)
5. initials.txt  the first letter of every name in users.tsv, UPPER-cased, one per line,
                 in file order, duplicates collapsed to one (uniq, not sort -u — keep order).
6. paired.txt    names (file order) from users.tsv and the ids (file order) side by side
                 as `name,id` — paste with a delimiter, not awk.

Why: these tools are a database engine in pieces. The two things that bite everyone are
collation (comm and join MERGE, so `sort` and `sort -n` are different orders) and the
field separator (a literal tab is $'\t' in bash and -t$'\t' on the command line).
EOF
}

hint() {
    cat <<'EOF'
export LC_ALL=C
join -t $'\t' <(sort -k1,1 users.tsv) <(sort -k1,1 logins.tsv) | cut -f2,3 | sort > joined.tsv
sort -t $'\t' -k2,2nr joined.tsv | head -3 | tr '\t' ' '
comm -23 <(sort old-users.txt) <(sort new-users.txt)
cut -f2 users.tsv | cut -c1 | tr a-z A-Z | uniq
paste -d, <(cut -f2 users.tsv) <(cut -f1 users.tsv)
EOF
}

setup() {
    printf '%s\t%s\n' 7 grace 2 ada 10 linus 3 alan 5 ken 1 dennis 8 barbara 12 margaret > users.tsv
    printf '%s\t%s\n' 2 14 10 3 5 27 1 9 8 5 99 100 3 27 > logins.tsv
    printf '%s\n' ada alan dennis grace ken rob > old-users.txt
    printf '%s\n' ada barbara dennis grace linus margaret > new-users.txt
}

check() {
    expect_lines joined.tsv "$(printf '%s\t%s\n' ada 14 alan 27 barbara 5 dennis 9 ken 27 linus 3)" "joined.tsv (ids 2,3,1,8,5,10 are in both; 7, 12, 99 are not)"
    if [[ -f top3.txt ]]; then
        local got; got="$(sed -n '1p;2p;3p' top3.txt | tr -s ' ')"
        # alan and ken tie at 27 — either order is right
        if [[ "$got" == $'alan 27\nken 27\nada 14' || "$got" == $'ken 27\nalan 27\nada 14' ]]; then ok "top3.txt: the two 27s then ada 14"
        else bad "top3.txt: expected alan/ken 27 (either order) then 'ada 14', got: $(tr '\n' '|' <<<"$got")"; fi
        expect_eq "top3.txt line count" "$(wc -l < top3.txt)" 3
    else bad "top3.txt is missing"; fi
    expect_lines removed.txt $'alan\nken\nrob' "removed.txt"
    expect_lines added.txt $'barbara\nlinus\nmargaret' "added.txt"
    expect_lines initials.txt $'G\nA\nL\nA\nK\nD\nB\nM' "initials.txt (file order; only ADJACENT duplicates collapse, so A appears twice)"
    expect_lines paired.txt $'grace,7\nada,2\nlinus,10\nalan,3\nken,5\ndennis,1\nbarbara,8\nmargaret,12' "paired.txt"
}

solve() {
    export LC_ALL=C
    join -t $'\t' <(LC_ALL=C sort -k1,1 users.tsv) <(LC_ALL=C sort -k1,1 logins.tsv) | cut -f2,3 | LC_ALL=C sort > joined.tsv
    LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 joined.tsv | head -3 | tr '\t' ' ' > top3.txt
    comm -23 <(LC_ALL=C sort old-users.txt) <(LC_ALL=C sort new-users.txt) > removed.txt
    comm -13 <(LC_ALL=C sort old-users.txt) <(LC_ALL=C sort new-users.txt) > added.txt
    cut -f2 users.tsv | cut -c1 | tr a-z A-Z | uniq > initials.txt
    paste -d, <(cut -f2 users.tsv) <(cut -f1 users.tsv) > paired.txt
}
