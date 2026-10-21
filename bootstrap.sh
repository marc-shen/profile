#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
if ! command -v python3 >/dev/null; then
 case $(uname -s) in
  Darwin) echo 'Install Xcode Command Line Tools first: xcode-select --install' >&2;;
  Linux) echo 'Install the bootstrap prerequisites: git, python3, curl and CA certificates using dnf/apt.' >&2;;
 esac
 exit 1
fi
exec python3 "$repo/scripts/bootstrap.py" "$@"
