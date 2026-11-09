#!/usr/bin/env bash
total=$(wc -l < access.log)
uniq=$(awk '{print $1}' access.log | LC_ALL=C sort -u | wc -l)
errors=$(awk '$(NF-1) >= 400' access.log | wc -l)
pct=$(awk -v e="$errors" -v t="$total" 'BEGIN { printf "%.1f", e*100/t }')
read -r sip scount < <(awk '$(NF-1)==401 { c[$1]++ } END { for (ip in c) print ip, c[ip] }' access.log | LC_ALL=C sort -k2,2nr | head -1)
printf '## Requests\ntotal: %s\n\n## Unique IPs\nunique: %s\n\n## Error rate\nerrors: %s (%s%%)\n\n## Top suspect\n%s with %s failed logins\n' \
    "$total" "$uniq" "$errors" "$pct" "$sip" "$scount" > report.md
