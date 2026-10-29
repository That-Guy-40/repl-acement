#!/usr/bin/env bash
##
##  demo/fetch-deps.sh — fetch the two things the demo can't ship in git:
##
##    demo/bin/yq                     Mike Farah's Go yq, v4.54.1 (yqrepl
##                                    refuses older builds whose --version
##                                    doesn't say 'mikefarah', e.g. 4.2.0)
##    demo/data/real/creditcard.csv   the public credit-card fraud dataset
##                                    (284,807 rows, 492 fraud; ~150 MB),
##                                    from OpenML (dataset 1597)
##
##  Both are idempotent: an existing file that checks out is kept.
##
set -uo pipefail
DEMO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

YQ_VER=v4.54.1
YQ_URL="https://github.com/mikefarah/yq/releases/download/$YQ_VER/yq_linux_amd64"
CSV_URL="https://www.openml.org/data/get_csv/1673544/phpKo8OWT"
CSV_SHA=a57f43b36bd695c8e984f481d9309c08a635e726068007f8d1751933e6866d86
CSV_ROWS=284808   # including the header

rc=0
mkdir -p "$DEMO_DIR/bin" "$DEMO_DIR/data/real"

# --- yq ----------------------------------------------------------------------
yq="$DEMO_DIR/bin/yq"
if [[ -x "$yq" ]] && "$yq" --version 2>&1 | grep -qi mikefarah; then
    echo "yq: already present ($("$yq" --version 2>&1))"
else
    case $(uname -s)-$(uname -m) in
        Linux-x86_64) ;;
        *) echo "yq: this script only knows the linux/amd64 build; get $YQ_VER for $(uname -s)/$(uname -m) from https://github.com/mikefarah/yq/releases and put it at $yq" >&2; rc=1 ;;
    esac
    if (( rc == 0 )); then
        echo "yq: downloading $YQ_VER"
        if curl -fsSL -m 300 -o "$yq.part" "$YQ_URL" && chmod +x "$yq.part" && "$yq.part" --version 2>&1 | grep -qi mikefarah; then
            mv "$yq.part" "$yq"; echo "yq: ok ($("$yq" --version 2>&1))"
        else
            rm -f "$yq.part"; echo "yq: download failed" >&2; rc=1
        fi
    fi
fi

# --- dataset -----------------------------------------------------------------
csv="$DEMO_DIR/data/real/creditcard.csv"
check_csv() { [[ $(wc -l < "$1") -eq $CSV_ROWS ]] && [[ $(sha256sum "$1" | cut -d' ' -f1) == "$CSV_SHA" ]]; }
if [[ -f "$csv" ]] && check_csv "$csv"; then
    echo "dataset: already present ($csv)"
else
    echo "dataset: downloading ~150 MB from OpenML"
    if curl -fsSL -m 1800 -o "$csv.part" "$CSV_URL" && check_csv "$csv.part"; then
        mv "$csv.part" "$csv"; echo "dataset: ok ($CSV_ROWS lines)"
    else
        echo "dataset: download failed or checksum mismatch" >&2
        [[ -f "$csv.part" ]] && { echo "        got $(wc -l < "$csv.part") lines, sha256 $(sha256sum "$csv.part" | cut -d' ' -f1)" >&2; rm -f "$csv.part"; }
        rc=1
    fi
fi

exit $rc
