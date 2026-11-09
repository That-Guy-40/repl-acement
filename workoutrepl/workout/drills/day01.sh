# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day01 — Readline and history: the line editor you already live in
DRILL_TITLE="Readline and history — the line editor you already live in"
DRILL_WEEK=1
DRILL_TOOLS=()

brief() {
    cat <<'EOF'
You type ten thousand lines a month into GNU Readline and most people have never
configured it. Today's outcome is three files in the fixture — nothing is installed into
your real ~ (do that yourself afterwards, if you like what you built).

1. inputrc — a readline init file that makes:
     • Up / Down arrows (\e[A / \e[B) do history-search-backward / -forward
       (type `ssh`, press Up: only lines starting with `ssh`)
     • set show-all-if-ambiguous on       (one Tab lists, not two)
     • set colored-stats on               (ls-style colours in completions)
     • set completion-ignore-case on
   Test it without touching ~/.inputrc:   INPUTRC=$PWD/inputrc bash -c 'bind -p; bind -v'

2. history.sh — a snippet you could source from .bashrc that sets
     HISTSIZE and HISTFILESIZE to at least 10000, HISTCONTROL so duplicates are
     ignored (ignoredups, ignoreboth or erasedups), HISTTIMEFORMAT to anything
     non-empty, and turns on the histappend shell option.
   Test:  bash --norc -c '. ./history.sh; shopt histappend; echo $HISTCONTROL'

3. answers.txt — three lines, one answer each, in this order:
     Q1  the readline KEY that inserts the last argument of the previous command
     Q2  the HISTORY designator (the `!` form) that means the same thing
     Q3  the readline KEY that opens the current line in $EDITOR
   Write keys the way `bind -p` does (\e. or M-. or Alt-. are all accepted; C-x C-e,
   Ctrl-x Ctrl-e likewise). The fixture's notes.txt restates the questions.

Why this is day 1: a fluent user edits the line, not the command. Alt-. alone saves
more retyping than any alias; Ctrl-x Ctrl-e turns a 200-char pipeline into an editor
buffer; history-search on the arrows turns history into a prefix index.
EOF
}

hint() {
    cat <<'EOF'
`bind -p` prints every binding in inputrc syntax — read the format there and copy it.
`man bash`, section READLINE, lists the variables (`set name value`) and the commands.
For Q1..Q3 try them at a prompt first: type `echo a b c`, Enter, then Alt-. — the `c`
appears. The HISTORY EXPANSION section names the `!` designators.
EOF
}

setup() {
    mkfile notes.txt \
        "Q1  which readline key inserts the LAST ARGUMENT of the previous command?" \
        "Q2  which history designator (the ! form) means the same thing?" \
        "Q3  which readline key opens the current line in \$EDITOR?" \
        "" \
        "answers.txt: one answer per line, Q1 first. Keys in bind -p notation (\\e. / M-. / C-x C-e all fine)."
}

check() {
    local out
    # 1. inputrc — observed through bind, not by reading the file: the binding has to be
    #    the one readline actually installs, in the file's own syntax.
    if [[ -f inputrc ]]; then
        out="$(INPUTRC="$PWD/inputrc" bash --norc --noprofile -c 'bind -p 2>/dev/null; bind -v 2>/dev/null' </dev/null)"
        # bash 5.3 prints the key as "\e[A"; bash 5.2 (Debian 13, Ubuntu 24.04) prints "\M-[A"
        # under LC_ALL=C — the same binding, two spellings. Accept the binding, not a spelling.
        if grep -qE '^"(\\e|\\M-)\[A": history-search-backward$' <<<"$out"; then ok "inputrc: Up arrow is history-search-backward"
        else bad "inputrc: Up arrow (\\e[A) is not bound to history-search-backward (bind -p does not list it)"; fi
        if grep -qE '^"(\\e|\\M-)\[B": history-search-forward$' <<<"$out"; then ok "inputrc: Down arrow is history-search-forward"
        else bad "inputrc: Down arrow (\\e[B) is not bound to history-search-forward"; fi
        local v
        for v in show-all-if-ambiguous colored-stats completion-ignore-case; do
            if grep -qE "^set $v on$" <<<"$out"; then ok "inputrc: set $v on"
            else bad "inputrc: readline variable $v is not on (bind -v shows it off)"; fi
        done
    else
        bad "inputrc is missing"
    fi
    # 2. history.sh — sourced into a clean bash and the resulting state inspected.
    if [[ -f history.sh ]]; then
        out="$(bash --norc --noprofile -c '. ./history.sh 2>/dev/null; printf "%s|%s|%s|%s|%s\n" "${HISTSIZE:-}" "${HISTFILESIZE:-}" "${HISTCONTROL:-}" "${HISTTIMEFORMAT:-}" "$(shopt -q histappend && echo on || echo off)"')"
        IFS='|' read -r hs hfs hc htf ha <<<"$out"
        [[ "$hs"  =~ ^-?[0-9]+$ ]] && (( hs < 0 || hs >= 10000 ))  && ok "history.sh: HISTSIZE=$hs" || bad "history.sh: HISTSIZE should be >= 10000 (or -1 for unlimited), got '${hs:-unset}'"
        [[ "$hfs" =~ ^-?[0-9]+$ ]] && (( hfs < 0 || hfs >= 10000 )) && ok "history.sh: HISTFILESIZE=$hfs" || bad "history.sh: HISTFILESIZE should be >= 10000 (or -1), got '${hfs:-unset}'"
        # HISTCONTROL is COLON-separated (ignoreboth:erasedups); fold the colons before testing.
        local hcl=":$hc:"
        if [[ "$hcl" == *:ignoredups:* || "$hcl" == *:ignoreboth:* || "$hcl" == *:erasedups:* ]]; then ok "history.sh: HISTCONTROL=$hc ignores duplicates"
        else bad "history.sh: HISTCONTROL should contain ignoredups, ignoreboth or erasedups, got '${hc:-unset}'"; fi
        [[ -n "$htf" ]] && ok "history.sh: HISTTIMEFORMAT is set" || bad "history.sh: HISTTIMEFORMAT is empty — timestamps are the point"
        [[ "$ha" == on ]] && ok "history.sh: shopt histappend is on" || bad "history.sh: shopt histappend is off (shopt -s histappend)"
    else
        bad "history.sh is missing"
    fi
    # 3. answers — normalised: lower-case, whitespace removed, Alt/Meta/Esc spellings folded.
    if [[ -f answers.txt ]]; then
        mapfile -t ans < <(sed -e 's/[[:space:]]//g' -e 's/.*/\L&/' answers.txt | sed -n '1,3p')
        local a1="${ans[0]:-}" a2="${ans[1]:-}" a3="${ans[2]:-}"
        case "$a1" in '\e.'|'m-.'|'alt-.'|'alt+.'|'esc.'|'meta-.'|'alt.'|'esc-.'|'\e-.') ok "Q1: $a1 (last argument of the previous command)";;
            *) bad "Q1: expected the readline key Alt-. (M-. / \\e.), got '${a1}'";; esac
        case "$a2" in '!$'|'!!:$'|'!-1$'|'!!$') ok "Q2: $a2 (history designator for the last argument)";;
            *) bad "Q2: expected the history designator !\$, got '${a2}'";; esac
        case "$a3" in 'c-xc-e'|'ctrl-xctrl-e'|'ctrl+xctrl+e'|'^x^e'|'\c-x\c-e'|'c-x,c-e'|'ctrl-x,ctrl-e'|'c-xe'|'ctrl-xe') ok "Q3: $a3 (edit the line in \$EDITOR)";;
            *) bad "Q3: expected the readline key Ctrl-x Ctrl-e (C-x C-e), got '${a3}'";; esac
    else
        bad "answers.txt is missing"
    fi
}

solve() {
    cat > inputrc <<'EOF'
# Up/Down search history by the prefix already typed
"\e[A": history-search-backward
"\e[B": history-search-forward
set show-all-if-ambiguous on
set colored-stats on
set completion-ignore-case on
EOF
    cat > history.sh <<'EOF'
# source from ~/.bashrc — a history worth searching
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups   # ignoreboth = ignoredups + ignorespace
HISTTIMEFORMAT='%F %T  '
shopt -s histappend                # append on exit instead of overwriting
EOF
    printf '%s\n' 'M-.' '!$' 'C-x C-e' > answers.txt
}
