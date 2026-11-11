#!/usr/bin/env python3
"""One-time, non-destructive layout migration. Run before replacing checkout files."""
from pathlib import Path
import sys

MOVES = {'scripts': 'libexec', 'platform': 'platforms', 'manifests': 'catalog',
         'shell': 'config/shell', 'emacs.d': 'config/emacs', 'helix': 'config/helix',
         'modulefiles': 'config/environment-modules', 'zshrc': 'config/shell/zshrc',
         'wezterm.lua': 'config/wezterm/wezterm.lua', 'starship.toml': 'config/starship/starship.toml',
         'archieve': 'archive'}


def migrate(repo):
    for old, new in MOVES.items():
        source, target = repo / old, repo / new
        if source.is_symlink() or not source.exists():
            continue
        if target.exists():
            raise RuntimeError(f'Both {source} and {target} exist; refusing to merge or discard either')
        target.parent.mkdir(parents=True, exist_ok=True)
        source.rename(target)
        source.symlink_to(new, target_is_directory=target.is_dir())
    nested = repo / 'platforms/steamdeck/scripts'
    if nested.is_dir() and not nested.is_symlink() and not (nested.parent / 'libexec').exists():
        nested.rename(nested.parent / 'libexec')
        nested.symlink_to('libexec', target_is_directory=True)
    # Aliases are retained locally for live processes. New checkouts do not contain them.
    print('Layout migrated without removing runtime data:', repo)


if __name__ == '__main__':
    migrate(Path(sys.argv[1]).resolve())
