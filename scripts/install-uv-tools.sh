#!/usr/bin/env bash
set -euo pipefail
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
source "${SOFTWARE_HOME:-$HOME/Software}/env.sh"
if [[ $# == 0 ]]; then
 while IFS= read -r name; do
  [[ -z $name || $name == \#* ]] || "$SOFTWARE_HOME/bin/uv" tool install --upgrade "$name"
 done < "$repo/manifests/uv-tools.txt"
else
 for name in "$@"; do "$SOFTWARE_HOME/bin/uv" tool install --upgrade "$name"; done
fi
