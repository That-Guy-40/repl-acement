#!/usr/bin/env bash
# Tutorial 3 (Krumins' AWK cheat sheet), step by step: F5 advances, the editor is live between steps.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd "$HERE/../../.." && pwd -P)
exec bash "$REPO/demo/play.sh" --dir "$HERE/steps" --interactive "$@"
