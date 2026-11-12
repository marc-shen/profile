#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
"$repo/bootstrap.sh"
exec bash "$repo/install.sh" steamdeck "$@"
