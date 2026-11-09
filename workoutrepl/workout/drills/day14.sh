# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day14 — BOSS 2: Vermilion Narwhal — log forensics
DRILL_TITLE="forensics on a web log — top talkers, 404s by hour, bytes by country, brute-force suspects, a report"
DRILL_WEEK=2
DRILL_TOOLS=(awk join)

brief() {
    cat <<'EOF'
⚔ BOSS BATTLE 2 — week 2's toolkit against one real-shaped problem.

access.log is 120 lines of combined-format web log (ip, [timestamp], "request", status,
bytes). geo.tsv maps `ip<TAB>country` for most — not all — of the ips. Produce:

1. top-ips.txt         the 5 busiest ips, `count ip`, most requests first; ties broken by
                       ip ascending (sort -k1,1nr -k2,2).
2. 404-by-hour.txt     `HH count` for every hour that has at least one 404, sorted by hour.
3. bytes-by-country.tsv  `country<TAB>bytes` — total response bytes per country for the
                       ips that ARE in geo.tsv, sorted by country. (join; mind the sort
                       on the key — and that geo.tsv does not cover every ip.)
4. unknown-ips.txt     the ips in the log that geo.tsv does NOT know, sorted.
5. suspects.txt        ips with 5 or more 401 responses, `ip count`, sorted by ip.
6. report.md           a Markdown report with exactly these four headings, each followed
                       by one line:
                         ## Requests        → `total: N`
                         ## Unique IPs      → `unique: N`
                         ## Error rate      → `errors: N (P%)`  where errors = status >= 400,
                                              P = errors*100/total, rounded to 1 decimal
                         ## Top suspect     → `<ip> with <count> failed logins`
                                              (the ip with the most 401s)

Why a boss: this is the incident-response shape. Nobody is asking for a program — they
are asking for six answers in ten minutes, and the person who can compose grep, awk,
sort, uniq and join at the prompt is the one who has them.
EOF
}

hint() {
    cat <<'EOF'
awk '{print $1}' access.log | sort | uniq -c | sort -k1,1nr -k2,2 | head -5 | awk '{print $1, $2}'
awk '$(NF-1)==404 { split($4, t, ":"); h[t[2]]++ } END { for (k in h) print k, h[k] }' | sort
join -t $'\t' <(awk '{print $1"\t"$NF}' access.log | sort -k1,1) <(sort -k1,1 geo.tsv) | awk -F'\t' '{b[$3]+=$2} END {...}'
comm -23 <(awk '{print $1}' access.log | sort -u) <(cut -f1 geo.tsv | sort)
EOF
}

# Deterministic log: a fixed table of (ip, hour, path, status, bytes) rows. No randomness.
_rows() {
    # ip hour path status bytes
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do printf '10.0.0.1 %02d /index.html 200 1000\n' $((i % 24)); done   # 20 ok
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do printf '10.0.0.2 %02d /api/data 200 500\n' $((i % 24)); done                      # 15 ok
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf '203.0.113.9 0%d /login 401 64\n' $(( i % 10 )); done                             # 12 x 401 (hours 01..09,00,01,02)
    for i in 1 2 3 4 5 6; do printf '198.51.100.7 1%d /login 401 64\n' $(( i % 10 )); done                                           # 6 x 401
    for i in 1 2 3; do printf '198.51.100.7 13 /login 200 300\n'; done                                                              # then logs in
    for i in 1 2 3 4 5 6 7 8; do printf '172.16.0.4 09 /old-page 404 128\n'; done                                                   # 8 x 404 @09
    for i in 1 2 3 4 5; do printf '172.16.0.4 14 /other-old 404 128\n'; done                                                        # 5 x 404 @14
    for i in 1 2; do printf '192.0.2.50 14 /missing 404 128\n'; done                                                                 # 2 x 404 @14
    for i in 1 2 3 4; do printf '192.0.2.50 15 /index.html 200 1000\n'; done                                                         # 4 ok
    for i in 1 2 3; do printf '10.0.0.3 16 /login 401 64\n'; done                                                                    # 3 x 401 (below threshold)
    for i in 1 2 3 4 5 6 7 8 9 10; do printf '10.0.0.3 %02d /admin 403 32\n' $((16 + i % 4)); done                                 # 10 x 403
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32; do printf '10.0.0.5 %02d /static/app.js 200 2048\n' $((i % 24)); done  # 32 ok
}
setup() {
    local ip hour path status bytes n=0
    while read -r ip hour path status bytes; do
        n=$((n+1))
        printf '%s - - [01/Mar/2024:%s:%02d:%02d +0000] "GET %s HTTP/1.1" %s %s\n' "$ip" "$hour" $((n % 60)) $(( (n*7) % 60 )) "$path" "$status" "$bytes"
    done < <(_rows) > access.log
    printf '%s\t%s\n' 10.0.0.1 LAN 10.0.0.2 LAN 10.0.0.3 LAN 10.0.0.5 LAN 203.0.113.9 Testland 198.51.100.7 Docland 172.16.0.4 Intranet > geo.tsv
    # 192.0.2.50 is deliberately absent from geo.tsv
}

check() {
    # counts: 10.0.0.5=32, 10.0.0.1=20, 10.0.0.2=15, 10.0.0.3=13, 172.16.0.4=13, 203.0.113.9=12, 198.51.100.7=9, 192.0.2.50=6 → total 120
    expect_lines top-ips.txt $'32 10.0.0.5\n20 10.0.0.1\n15 10.0.0.2\n13 10.0.0.3\n13 172.16.0.4' "top-ips.txt (13 ties: 10.0.0.3 before 172.16.0.4)"
    expect_lines 404-by-hour.txt $'09 8\n14 7' "404-by-hour.txt"
    # bytes: LAN = 20*1000 + 15*500 + 10*32 + 3*64 + 32*2048 = 20000+7500+320+192+65536 = 93548
    #        Testland = 12*64 = 768 ; Docland = 6*64 + 3*300 = 1284 ; Intranet = 13*128 = 1664
    expect_lines bytes-by-country.tsv "$(printf '%s\t%s\n' Docland 1284 Intranet 1664 LAN 93548 Testland 768)" "bytes-by-country.tsv"
    expect_lines unknown-ips.txt "192.0.2.50" "unknown-ips.txt"
    expect_lines suspects.txt $'198.51.100.7 6\n203.0.113.9 12' "suspects.txt (>= 5 401s; 10.0.0.3 has only 3)"
    if [[ -f report.md ]]; then
        local body; body="$(grep -vE '^\s*$' report.md)"
        # errors: 401s 12+6+3=21, 404s 15, 403s 10 → 46 of 120 = 38.333 → 38.3%
        expect_eq "report.md" "$body" $'## Requests\ntotal: 120\n## Unique IPs\nunique: 8\n## Error rate\nerrors: 46 (38.3%)\n## Top suspect\n203.0.113.9 with 12 failed logins'
    else bad "report.md is missing"; fi
}

solve() {
    awk '{print $1}' access.log | LC_ALL=C sort | uniq -c | LC_ALL=C sort -k1,1nr -k2,2 | head -5 | awk '{print $1, $2}' > top-ips.txt
    awk '$(NF-1)==404 { split($4, t, ":"); h[t[2]]++ } END { for (k in h) print k, h[k] }' access.log | LC_ALL=C sort > 404-by-hour.txt
    join -t $'\t' <(awk '{print $1"\t"$NF}' access.log | LC_ALL=C sort -k1,1) <(LC_ALL=C sort -k1,1 geo.tsv) \
        | awk -F'\t' '{ b[$3] += $2 } END { for (c in b) printf "%s\t%d\n", c, b[c] }' | LC_ALL=C sort > bytes-by-country.tsv
    comm -23 <(awk '{print $1}' access.log | LC_ALL=C sort -u) <(cut -f1 geo.tsv | LC_ALL=C sort) > unknown-ips.txt
    awk '$(NF-1)==401 { c[$1]++ } END { for (ip in c) if (c[ip] >= 5) print ip, c[ip] }' access.log | LC_ALL=C sort > suspects.txt
    {
        total=$(wc -l < access.log)
        uniq=$(awk '{print $1}' access.log | LC_ALL=C sort -u | wc -l)
        errors=$(awk '$(NF-1) >= 400' access.log | wc -l)
        pct=$(awk -v e="$errors" -v t="$total" 'BEGIN { printf "%.1f", e*100/t }')
        read -r sip scount < <(awk '$(NF-1)==401 { c[$1]++ } END { for (ip in c) print ip, c[ip] }' access.log | LC_ALL=C sort -k2,2nr | head -1)
        printf '## Requests\ntotal: %s\n\n## Unique IPs\nunique: %s\n\n## Error rate\nerrors: %s (%s%%)\n\n## Top suspect\n%s with %s failed logins\n' \
            "$total" "$uniq" "$errors" "$pct" "$sip" "$scount"
    } > report.md
}
