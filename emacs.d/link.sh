#!/usr/bin/env bash
#
# Link this repository's Emacs configuration into ~/.emacs.d, and its commands
# into ~/.local/bin.
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
#        BIN_HOME=/some/where/bin ./link.sh

set -euo pipefail

# The entries Emacs can only find inside `user-emacs-directory' itself.  `lisp'
# is reached through `load-path' and needs no link, but one is kept anyway so
# that `~/.emacs.d' shows the whole configuration rather than half of it.
entries=(init.el early-init.el lisp snippets)

# The entries that belong on `PATH' instead, so that `em' works from any shell.
commands=(em)

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
bin_target=${BIN_HOME:-$HOME/.local/bin}

printf 'source: %s\ntarget: %s\n   bin: %s\n\n' \
  "$source_directory" "$target" "$bin_target"
$dry_run && printf 'dry run: nothing will be changed\n\n'

linked=0 relinked=0 unchanged=0 saved=0 missing=0

# Link one entry of the repository into one directory.  Everything the script
# reports and counts happens here, so the two directories are treated alike.
link_entry() {
  local entry=$1 destination=$2
  local source_path=$source_directory/$entry
  local link_path=$destination/$entry
  local current backup

  if [ ! -e "$source_path" ]; then
    printf '  %-16s skipped, not in the repository\n' "$entry"
    missing=$((missing + 1))
    return
  fi

  # -L rather than -e: a link whose target is gone still occupies the name, and
  # -e reports false for it.
  if [ -L "$link_path" ]; then
    current=$(readlink "$link_path")
    if [ "$current" = "$source_path" ]; then
      printf '  %-16s ok\n' "$entry"
      unchanged=$((unchanged + 1))
      return
    fi
    printf '  %-16s relinked, was -> %s\n' "$entry" "$current"
    $dry_run || ln -sfn "$source_path" "$link_path"
    relinked=$((relinked + 1))
    return
  fi

  if [ -e "$link_path" ]; then
    backup=$link_path.backup.$(date +%Y%m%d%H%M%S)
    printf '  %-16s existing file kept as %s\n' "$entry" "$(basename "$backup")"
    if ! $dry_run; then
      mv -- "$link_path" "$backup"
      ln -sfn "$source_path" "$link_path"
    fi
    saved=$((saved + 1))
    return
  fi

  printf '  %-16s linked\n' "$entry"
  $dry_run || ln -sfn "$source_path" "$link_path"
  linked=$((linked + 1))
}

# A pull that renames or removes a tracked file leaves its link behind, pointing
# at nothing.  Emacs would not care, but a dangling link is confusing to read,
# so clear the ones this script is responsible for.  Only links into this
# repository are considered, which is what makes the sweep safe to run over a
# shared directory like ~/.local/bin.
stale=0
remove_stale_links() {
  local destination=$1 link_path current

  for link_path in "$destination"/*; do
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
}

$dry_run || mkdir -p "$target" "$bin_target"

for entry in "${entries[@]}"; do
  link_entry "$entry" "$target"
done

for entry in "${commands[@]}"; do
  link_entry "$entry" "$bin_target"
done

remove_stale_links "$target"
remove_stale_links "$bin_target"

printf '\n%d linked, %d relinked, %d already correct' "$linked" "$relinked" "$unchanged"
[ "$saved" -gt 0 ] && printf ', %d saved aside' "$saved"
[ "$stale" -gt 0 ] && printf ', %d stale removed' "$stale"
[ "$missing" -gt 0 ] && printf ', %d missing from the repository' "$missing"
printf '\n'

if [ "$linked" -gt 0 ] || [ "$relinked" -gt 0 ]; then
  printf '\nStart Emacs, then run M-x my-install-packages to fetch the packages.\n'
fi

# A link nobody can reach is no better than no link at all.
case :$PATH: in
  *:"$bin_target":*) ;;
  *) printf '\n%s is not on PATH; add it to run em by name.\n' "$bin_target" ;;
esac
