# shellcheck shell=bash disable=SC2034
# ^ sourced by bin/workout, never executed, so no shebang; DRILL_* are read by the trainer
# day02 — Brace expansion and globbing
DRILL_TITLE="Brace expansion and globbing — extglob, globstar, dotglob, nocaseglob"
DRILL_WEEK=1
DRILL_TOOLS=()
# extglob must be on when bash PARSES `!(keep)` below, not just when it runs — so it is
# set here, at file level, before solve() is defined.
shopt -s extglob

brief() {
    cat <<'EOF'
The fixture is incoming/ — a small, slightly hostile download directory. Produce:

1. project/ — the tree  project/{src,test,docs}/{alpha,beta,gamma}/  (nine directories)
   plus  project/CHANGELOG-v{1..3}.md  (three empty files)  — in ONE mkdir and ONE touch.

2. Delete every *.tmp in incoming/ EXCEPT keep.tmp — including the dot-file one
   (.cache.tmp) — in one command, with no `find` and no `rm` loop. Hints in the name:
   shopt -s extglob dotglob.  Leave everything else in incoming/ untouched.

3. logs.txt — every *.log under incoming/ at ANY depth, one path per line, sorted,
   written with printf and a ** glob (shopt -s globstar), not find.

4. images.txt — every JPEG in incoming/ (top level) regardless of the CASE of its
   extension (.jpg .JPG .Jpg …), one path per line, sorted. Two routes: nocaseglob, or
   a character-class glob. Either is fine; the result is what is graded.

Why: the shell expands before the command runs. If you can predict the expansion you
never need `ls | grep`, and you stop writing loops for things one glob already says.
EOF
}

hint() {
    cat <<'EOF'
mkdir -p project/{src,test,docs}/{alpha,beta,gamma}      # braces nest and multiply
shopt -s extglob dotglob; echo incoming/!(keep).tmp      # ALWAYS echo a destructive glob first
shopt -s globstar;  printf '%s\n' incoming/**/*.log | sort
shopt -s nocaseglob; printf '%s\n' incoming/*.jpg | sort
EOF
}

setup() {
    mkdir -p incoming/sub/deeper
    local f
    for f in report-2024-01.txt report-2024-02.txt notes.md Notes.MD scratch.tmp keep.tmp draft2.tmp \
             img001.JPG img002.jpg img003.Jpg photo.jpeg a.log b.log; do : > "incoming/$f"; done
    : > incoming/.cache.tmp
    : > incoming/.hidden.log
    : > incoming/sub/c.log
    : > incoming/sub/deeper/d.log
    : > incoming/sub/not-a-log.txt
}

check() {
    local d f
    for d in src test docs; do for f in alpha beta gamma; do expect_dir "project/$d/$f"; done; done
    for f in 1 2 3; do expect_file "project/CHANGELOG-v$f.md"; done
    expect_no_path incoming/scratch.tmp
    expect_no_path incoming/draft2.tmp
    expect_no_path incoming/.cache.tmp "incoming/.cache.tmp (the dot-file — dotglob)"
    expect_file incoming/keep.tmp "incoming/keep.tmp (the exception)"
    for f in report-2024-01.txt notes.md Notes.MD img001.JPG a.log .hidden.log sub/c.log sub/not-a-log.txt; do
        [[ -e "incoming/$f" ]] || bad "incoming/$f was deleted — only the .tmp files should go"
    done
    ok "the non-.tmp files in incoming/ are intact"
    expect_lines logs.txt $'incoming/.hidden.log\nincoming/a.log\nincoming/b.log\nincoming/sub/c.log\nincoming/sub/deeper/d.log' \
        "logs.txt (every .log at any depth — ** recurses; dotglob catches .hidden.log)"
    expect_lines images.txt $'incoming/img001.JPG\nincoming/img002.jpg\nincoming/img003.Jpg' \
        "images.txt (the three .jpg/.JPG/.Jpg — .jpeg is a different extension)"
}

solve() {
    mkdir -p project/{src,test,docs}/{alpha,beta,gamma}
    touch project/CHANGELOG-v{1..3}.md
    shopt -s extglob dotglob globstar
    rm -- incoming/!(keep).tmp
    printf '%s\n' incoming/**/*.log | LC_ALL=C sort > logs.txt
    printf '%s\n' incoming/*.[jJ][pP][gG] | LC_ALL=C sort > images.txt
    shopt -u extglob dotglob globstar
}
