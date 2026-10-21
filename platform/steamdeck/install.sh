#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
exec "$repo/bootstrap.sh" install "$@"
