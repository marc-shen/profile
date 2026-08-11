#!/usr/bin/env bash
#
# Link this repository's Emacs configuration into ~/.emacs.d.
#
# Run it once on a new machine, and again after `git pull' whenever the set of
# top-level files changed -- it is idempotent, so running it when nothing needs
# doing is harmless and prints only "ok".  Ordinary edits to a tracked file need
# no run at all: the links point at the working tree, so a pull is visible to
# Emacs immediately.
#
# Nothing is ever deleted.  A real file where a link belongs is renamed aside
# with a timestamp, never overwritten.
#
# Usage: ./link.sh [--dry-run] [target-directory]
#        EMACS_HOME=/some/where ./link.sh

set -euo pipefail

# The entries Emacs can only find inside `user-emacs-directory' itself.  `lisp'
# is reached through `load-path' and needs no link, but one is kept anyway so
# that `~/.emacs.d' shows the whole configuration rather than half of it.
entries=(init.el early-init.el lisp snippets)

dry_run=false
target=""
for argument in "$@"; do
  case $argument in
    --dry-run|-n) dry_run=true ;;
    -h|--help) sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) printf 'link.sh: unknown option %s\n' "$argument" >&2; exit 2 ;;
    *) target=$argument ;;
  esac
done

# `pwd -P' resolves every symlink in the path, so the links record where the
# repository really is even when the script was reached through one.
source_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
target=${target:-${EMACS_HOME:-$HOME/.emacs.d}}

printf 'source: %s\ntarget: %s\n\n' "$source_directory" "$target"
$dry_run && printf 'dry run: nothing will be changed\n\n'

$dry_run || mkdir -p "$target"

linked=0 relinked=0 unchanged=0 saved=0 missing=0

for entry in "${entries[@]}"; do
  source_path=$source_directory/$entry
  link_path=$target/$entry

  if [ ! -e "$source_path" ]; then
    printf '  %-16s skipped, not in the repository\n' "$entry"
    missing=$((missing + 1))
    continue
  fi

  # -L rather than -e: a link whose target is gone still occupies the name, and
  # -e reports false for it.
  if [ -L "$link_path" ]; then
    current=$(readlink "$link_path")
    if [ "$current" = "$source_path" ]; then
      printf '  %-16s ok\n' "$entry"
      unchanged=$((unchanged + 1))
      continue
    fi
    printf '  %-16s relinked, was -> %s\n' "$entry" "$current"
    $dry_run || ln -sfn "$source_path" "$link_path"
    relinked=$((relinked + 1))
    continue
  fi

  if [ -e "$link_path" ]; then
    backup=$link_path.backup.$(date +%Y%m%d%H%M%S)
    printf '  %-16s existing file kept as %s\n' "$entry" "$(basename "$backup")"
    if ! $dry_run; then
      mv -- "$link_path" "$backup"
      ln -sfn "$source_path" "$link_path"
    fi
    saved=$((saved + 1))
    continue
  fi

  printf '  %-16s linked\n' "$entry"
  $dry_run || ln -sfn "$source_path" "$link_path"
  linked=$((linked + 1))
done

# A pull that renames or removes a tracked file leaves its link behind, pointing
# at nothing.  Emacs would not care, but a dangling link is confusing to read,
# so clear the ones this script is responsible for.
stale=0
for link_path in "$target"/*; do
  [ -L "$link_path" ] || continue
  current=$(readlink "$link_path")
  case $current in
    "$source_directory"/*) [ -e "$current" ] && continue ;;
    *) continue ;;
  esac
  printf '  %-16s removed, dangling -> %s\n' "$(basename "$link_path")" "$current"
  $dry_run || rm -- "$link_path"
  stale=$((stale + 1))
done

printf '\n%d linked, %d relinked, %d already correct' "$linked" "$relinked" "$unchanged"
[ "$saved" -gt 0 ] && printf ', %d saved aside' "$saved"
[ "$stale" -gt 0 ] && printf ', %d stale removed' "$stale"
[ "$missing" -gt 0 ] && printf ', %d missing from the repository' "$missing"
printf '\n'

if [ "$linked" -gt 0 ] || [ "$relinked" -gt 0 ]; then
  printf '\nStart Emacs, then run M-x my-install-packages to fetch the packages.\n'
fi
