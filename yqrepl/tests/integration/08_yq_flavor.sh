#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
##
##  integration/08_yq_flavor.sh - _yqrepl_is_mikefarah tells Mike Farah's Go yq
##  from the unrelated Python "yq". Uses synthetic yq stubs so the check is
##  deterministic regardless of which yq (if any) is actually installed.
##

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YQREPL="$(cd "$TESTS_DIR/../.." && pwd)/yqrepl"
source "$TESTS_DIR/../helpers.sh"
source "$YQREPL"

fakedir=$(mktemp -d)
trap 'rm -rf "$fakedir"' EXIT

# --- a Mike Farah version string is accepted ---
cat > "$fakedir/yq" <<'FAKE'
#!/bin/sh
echo "yq (https://github.com/mikefarah/yq/) version v4.44.3"
FAKE
chmod +x "$fakedir/yq"
( PATH="$fakedir:$PATH"; _yqrepl_is_mikefarah ); rc=$?
assert_equals "Mike Farah's yq is recognized" "0" "$rc"

# --- the Python yq (kislyuk) version string is rejected ---
cat > "$fakedir/yq" <<'FAKE'
#!/bin/sh
echo "yq 3.2.3"
FAKE
( PATH="$fakedir:$PATH"; _yqrepl_is_mikefarah ); rc=$?
assert_equals "the Python yq is rejected" "1" "$rc"

# --- launching yqrepl with the wrong yq fails fast with a clear message ---
out=$( PATH="$fakedir:$PATH" HOME="$fakedir" bash "$YQREPL" 2>&1 ); rc=$?
assert_equals "yqrepl refuses to launch with the wrong yq" "1" "$rc"
if echo "$out" | grep -qi "Mike Farah"; then
    pass "the refusal message names the required tool"
else
    fail "refusal message should name Mike Farah's yq" "got: $out"
fi

summary
