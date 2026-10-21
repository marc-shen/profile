#!/usr/bin/env bash
# Link the COMPLETE emacs.d directory, preserving runtime files and backups.
# Usage: bash emacs.d/link.sh [--dry-run]
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
exec python3 "$repo/scripts/deploy.py" link --only emacs "$@"
