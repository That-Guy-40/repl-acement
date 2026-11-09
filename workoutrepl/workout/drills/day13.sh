# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day13 — Regular expressions
DRILL_TITLE="Regular expressions — BRE vs ERE vs PCRE, anchors, classes, alternation, backreferences"
DRILL_WEEK=2
DRILL_TOOLS=(grep)

brief() {
    cat <<'EOF'
input.txt is 24 lines of mixed junk: e-mail addresses, dates in several formats, IPv4
addresses (some invalid), hex colours, phone numbers, and decoys. Produce:

1. emails.txt     lines containing a plausible e-mail: user@host.tld where user is
                  [A-Za-z0-9._%+-]+, host [A-Za-z0-9.-]+, tld 2+ letters. (lines, not matches)
2. iso-dates.txt  the DATE TOKENS (not lines) of the form YYYY-MM-DD, one per line, in
                  file order. 2024-13-45 is still a token (format, not validity).
3. hex.txt        the hex colour tokens `#` + exactly 6 hex digits, as whole words
                  (#12345 and #1234567 must not match), in file order.
4. ipv4.txt       VALID IPv4 addresses (each octet 0-255), one per line, file order. A
                  regex can do this with alternation — or grep the candidates and filter
                  with awk/bash; the result is what is graded.
5. doubled.txt    lines containing a doubled WORD (`the the`, `is is`) — a backreference.
6. pattern-bre.txt  the BASIC-regex spelling of the extended pattern  ^(ab|cd)+x?$
                  (one line, the pattern only). The checker runs `grep -f` with YOUR
                  pattern (no -E) over a set of probe strings and compares matches.

Why: grep -E, sed -E and awk speak ERE; grep and sed without -E speak BRE, where
( ) | + ? are literal unless escaped; grep -P is PCRE with \d and lookarounds. Knowing
which dialect you are in is most of regex fluency; the rest is anchoring and classes.
EOF
}

hint() {
    cat <<'EOF'
grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' input.txt
grep -oE '\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b' input.txt
grep -oE '(^|[^#[:alnum:]])#[0-9a-fA-F]{6}\b' …  or simpler: grep -owE '#[0-9a-fA-F]{6}'
octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'; grep -oE "\b$octet(\.$octet){3}\b"
grep -E '\b([a-z]+) \1\b' input.txt
In BRE: \( \) for groups, \| for alternation (GNU), \+ and \? (GNU)  →  ^\(ab\|cd\)\+x\?$
EOF
}

setup() {
    cat > input.txt <<'EOF'
contact ada@example.com for details
not an email: ada@localhost
released 2024-03-15 and again 2024-04-01
US style 03/15/2024 is not ISO
bogus 2024-13-45 still looks like a date token
colour #ff8800 and #FFF and #1234567 and #abcdef
short #12345 is not a colour
server 10.0.0.5 and gateway 192.168.1.1
invalid 256.1.1.1 and 10.0.0.999 and 1.2.3
edge 0.0.0.0 and 255.255.255.255
call +1 555 0100 or 555-0199
the the quick brown fox
this is is a test
no doubles here at all
grace.hopper+navy@mil.example.org wrote
bad@@double.at
phone: (555) 010-0100
ab ab ab x
#000000 at the start of a line
ip-like 1.2.3.4.5 is five octets
version 12.34.56.78 is an ip too
the cat sat on the mat
mixed: alan@turing.ac.uk 2024-01-01 #c0ffee 127.0.0.1
end end
EOF
}

check() {
    expect_lines emails.txt $'contact ada@example.com for details\ngrace.hopper+navy@mil.example.org wrote\nmixed: alan@turing.ac.uk 2024-01-01 #c0ffee 127.0.0.1' \
        "emails.txt (ada@localhost has no TLD; bad@@double.at fails the user/host shape)"
    expect_lines iso-dates.txt $'2024-03-15\n2024-04-01\n2024-13-45\n2024-01-01' "iso-dates.txt (tokens, in order)"
    expect_lines hex.txt $'#ff8800\n#abcdef\n#000000\n#c0ffee' "hex.txt (#FFF, #12345 and #1234567 excluded)"
    expect_lines ipv4.txt $'10.0.0.5\n192.168.1.1\n0.0.0.0\n255.255.255.255\n12.34.56.78\n127.0.0.1' \
        "ipv4.txt (256.x, .999 and 1.2.3 rejected; 1.2.3.4.5 is not an address — it has five parts)"
    expect_lines doubled.txt $'the the quick brown fox\nthis is is a test\nab ab ab x\nend end' "doubled.txt (backreference)"
    if [[ -f pattern-bre.txt ]]; then
        local probes=$'ab\ncd\nabcd\nabcdab\nabx\ncdcdx\nx\nabxx\nabc\n\nababcdcdabx\naxb'
        local want got
        want="$(grep -E '^(ab|cd)+x?$' <<<"$probes")"
        got="$(grep -f pattern-bre.txt <<<"$probes" 2>&1)"
        expect_eq "pattern-bre.txt matches the same probes as the ERE" "$got" "$want"
        if grep -qE '[^\\][(|+?]' pattern-bre.txt; then bad "pattern-bre.txt contains an unescaped ( | + or ? — that is ERE syntax; in BRE they are literal unless backslashed"; else ok "pattern-bre.txt uses BRE escapes"; fi
    else bad "pattern-bre.txt is missing"; fi
}

solve() {
    grep -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' input.txt | grep -vE '@@' > emails.txt
    grep -oE '\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b' input.txt > iso-dates.txt
    grep -owE '#[0-9a-fA-F]{6}' input.txt > hex.txt
    # no `local` here: `workout solution` prints this body for PASTING at a prompt, where
    # `local` is an error ("can only be used in a function") and would leave $o empty
    o='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
    grep -oE "(^|[^0-9.])$o(\.$o){3}([^0-9.]|$)" input.txt | grep -oE "$o(\.$o){3}" > ipv4.txt
    grep -E '\b([a-z]+) \1\b' input.txt > doubled.txt
    printf '%s\n' '^\(ab\|cd\)\+x\?$' > pattern-bre.txt
}
