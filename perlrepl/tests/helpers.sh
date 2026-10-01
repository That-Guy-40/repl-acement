#!/usr/bin/env bash
##
##  tests/helpers.sh - shared test utilities for perlrepl tests
##

PASS=0
FAIL=0
_ERRORS=()

pass() { echo "  PASS: $1"; (( PASS++ )) || true; }
fail() { echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "        $2"; (( FAIL++ )) || true; _ERRORS+=("$1"); }

assert_equals() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc" "expected=$(printf '%q' "$expected"), got=$(printf '%q' "$actual")"
    fi
}

assert_file_contains() {
    local desc="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then
        pass "$desc"
    else
        fail "$desc" "file '$file' does not contain: $needle"
    fi
}

assert_file_not_contains() {
    local desc="$1" needle="$2" file="$3"
    if ! grep -qF -- "$needle" "$file"; then
        pass "$desc"
    else
        fail "$desc" "file '$file' unexpectedly contains: $needle"
    fi
}

assert_empty() {
    local desc="$1" file="$2"
    if [[ ! -s "$file" ]]; then
        pass "$desc"
    else
        fail "$desc" "expected empty file, got: $(head -1 "$file")"
    fi
}

assert_nonempty() {
    local desc="$1" file="$2"
    if [[ -s "$file" ]]; then
        pass "$desc"
    else
        fail "$desc" "file '$file' is empty"
    fi
}

assert_command_found() {
    local desc="$1" cmd="$2"
    if command -v "$cmd" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc" "'$cmd' not found in PATH"
    fi
}

assert_output_equals() {
    local desc="$1" expected="$2"
    shift 2
    local actual
    actual=$("$@" 2>&1)
    assert_equals "$desc" "$expected" "$actual"
}

assert_output_contains() {
    local desc="$1" needle="$2"
    shift 2
    local actual
    actual=$("$@" 2>&1)
    if echo "$actual" | grep -qF -- "$needle"; then
        pass "$desc"
    else
        fail "$desc" "output does not contain '$needle'; got: $actual"
    fi
}

summary() {
    local name
    name=$(basename "${BASH_SOURCE[1]:-$0}")
    echo ""
    echo "$name: $PASS passed, $FAIL failed"
    if (( FAIL > 0 )); then
        for err in "${_ERRORS[@]}"; do
            echo "  - $err"
        done
    fi
    (( FAIL == 0 ))
}
