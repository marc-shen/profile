#!/usr/bin/env python3
"""Install/update the shared Zsh plugins from upstream; refuse to discard local changes."""
import os
from pathlib import Path
import subprocess as sp

repo = Path(__file__).resolve().parents[1]
root = Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software')))
plugins = root / 'share/zsh/plugins'
plugins.mkdir(parents=True, exist_ok=True)
records = {}
for line in (repo / 'manifests/zsh-plugins.sources').read_text().splitlines():
    if not line or line.startswith('#'):
        continue
    name, _previous_commit, url = line.split()
    path = plugins / name
    if not path.exists():
        sp.run(['git', 'clone', '--depth=1', '--no-checkout', url, str(path)], check=True)
    else:
        dirty = sp.check_output(['git', '-C', str(path), 'status', '--porcelain'], text=True)
        if dirty:
            raise SystemExit(f'{path}: local changes; kept untouched, resolve before updating')
    sp.run(['git', '-C', str(path), 'fetch', '--depth=1', 'origin', 'HEAD'], check=True)
    commit = sp.check_output(['git', '-C', str(path), 'rev-parse', 'FETCH_HEAD'], text=True).strip()
    sp.run(['git', '-C', str(path), 'checkout', '--detach', commit], check=True)
    records[name] = {'url': url, 'commit': commit}
import json
(root / 'share/zsh/plugins-installed.json').write_text(json.dumps(records, indent=2) + '\n')
completions = root / 'share/zsh/completions'
completions.mkdir(parents=True, exist_ok=True)
import shutil
for name, args in [('pixi', ['completion', '--shell', 'zsh']), ('uv', ['generate-shell-completion', 'zsh'])]:
    exe = root / 'bin' / name
    executable = str(exe) if exe.exists() else shutil.which(name)
    if executable:
        result = sp.run([executable, *args], text=True, capture_output=True, check=True)
        (completions / ('_' + name)).write_text(result.stdout)
