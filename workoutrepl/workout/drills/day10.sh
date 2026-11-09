# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day10 — awk
DRILL_TITLE="awk — fields, separators, associative arrays, END, printf"
DRILL_WEEK=2
DRILL_TOOLS=(awk)

brief() {
    cat <<'EOF'
sales.csv is a header plus rows of  region,product,qty,unit_price.  access.log is a
tiny web log. Produce four files with awk (sort may follow it):

1. by-region.txt   `region<TAB>revenue` where revenue = sum(qty*unit_price), printed with
                   two decimals, one line per region, sorted by region.
2. top-product.txt the single product with the largest TOTAL qty across all rows, as
                   `product qty`  (e.g. `widget 42`).
3. status-hist.txt from access.log: `status count`, one per distinct HTTP status, sorted
                   by status. The status is the field after the quoted request — count
                   fields from the END ($(NF-1)) rather than the start.
4. wide.txt        sales.csv without its header, as fixed-width columns:
                   printf "%-6s %-8s %4d %8.2f\n"  (region, product, qty, unit_price).

Why: awk is the language for "per line, split into fields, remember something, report
at the end". -F sets the separator, $NF counts from the right, arrays index by string,
END runs once — four ideas, and most one-liners are made of nothing else.
EOF
}

hint() {
    cat <<'EOF'
awk -F, 'NR>1 { r[$1] += $3*$4 } END { for (k in r) printf "%s\t%.2f\n", k, r[k] }' sales.csv | sort
awk -F, 'NR>1 { q[$2]+=$3 } END { for (p in q) if (q[p]>m) { m=q[p]; best=p }; print best, m }' sales.csv
awk '{ s[$(NF-1)]++ } END { for (c in s) print c, s[c] }' access.log | sort
EOF
}

setup() {
    cat > sales.csv <<'EOF'
region,product,qty,unit_price
north,widget,10,2.50
south,gadget,3,10.00
north,gadget,2,10.00
east,widget,7,2.50
south,widget,25,2.50
east,doohickey,1,99.99
north,doohickey,2,99.99
south,gadget,4,10.00
EOF
    cat > access.log <<'EOF'
10.0.0.1 - - [01/Mar/2024:10:00:00 +0000] "GET / HTTP/1.1" 200 512
10.0.0.2 - - [01/Mar/2024:10:00:01 +0000] "GET /missing HTTP/1.1" 404 128
10.0.0.1 - - [01/Mar/2024:10:00:02 +0000] "POST /login HTTP/1.1" 401 64
10.0.0.3 - - [01/Mar/2024:10:00:03 +0000] "GET /about HTTP/1.1" 200 2048
10.0.0.2 - - [01/Mar/2024:10:00:04 +0000] "GET /also-missing HTTP/1.1" 404 128
10.0.0.1 - - [01/Mar/2024:10:00:05 +0000] "POST /login HTTP/1.1" 200 96
10.0.0.4 - - [01/Mar/2024:10:00:06 +0000] "GET /admin HTTP/1.1" 403 32
EOF
}

check() {
    # north: 25 + 20 + 199.98 = 244.98 ; south: 30 + 62.5 + 40 = 132.50 ; east: 17.5 + 99.99 = 117.49
    expect_lines by-region.txt $'east\t117.49\nnorth\t244.98\nsouth\t132.50' "by-region.txt"
    # widget 10+7+25 = 42 ; gadget 3+2+4 = 9 ; doohickey 3
    expect_lines top-product.txt "widget 42" "top-product.txt"
    expect_lines status-hist.txt $'200 3\n401 1\n403 1\n404 2' "status-hist.txt"
    expect_lines wide.txt "$(printf '%-6s %-8s %4d %8.2f\n' north widget 10 2.50 south gadget 3 10 north gadget 2 10 east widget 7 2.5 south widget 25 2.5 east doohickey 1 99.99 north doohickey 2 99.99 south gadget 4 10)" \
        "wide.txt (fixed-width printf)"
}

solve() {
    awk -F, 'NR>1 { r[$1] += $3*$4 } END { for (k in r) printf "%s\t%.2f\n", k, r[k] }' sales.csv | LC_ALL=C sort > by-region.txt
    awk -F, 'NR>1 { q[$2]+=$3 } END { for (p in q) if (q[p]>m) { m=q[p]; best=p }; print best, m }' sales.csv > top-product.txt
    awk '{ s[$(NF-1)]++ } END { for (c in s) print c, s[c] }' access.log | LC_ALL=C sort > status-hist.txt
    awk -F, 'NR>1 { printf "%-6s %-8s %4d %8.2f\n", $1, $2, $3, $4 }' sales.csv > wide.txt
}
