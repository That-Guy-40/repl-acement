#!/usr/bin/env bash
# Tutorial 1, step by step: F5 advances; between steps the editor is yours.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd "$HERE/../../.." && pwd -P)
exec bash "$REPO/demo/play.sh" --dir "$HERE/steps" --interactive "$@"
