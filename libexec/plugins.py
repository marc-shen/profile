#!/usr/bin/env python3
"""Manage Zsh plugins without discarding local changes or failed checkout state."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
import tempfile
from config_data import plugin_sources

REPO = Path(__file__).resolve().parents[1]


def sources():
    return plugin_sources(REPO)


def git(path, *args):
    result = sp.run(['git', '-C', str(path), *args], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{path.name}: git {args[0]} failed: {result.stderr.strip()}')
    return result.stdout.strip()


def inspect(path):
    if not path.exists():
        return 'missing', '-'
    if not (path / '.git').is_dir():
        return 'invalid (not a Git checkout)', '-'
    commit = git(path, 'rev-parse', 'HEAD')
    return ('modified' if git(path, 'status', '--porcelain') else 'installed'), commit


def update(path, url, missing_only=False):
    if path.exists():
        state, commit = inspect(path)
        if state.startswith('invalid'):
            raise RuntimeError(f'{path}: {state}; kept untouched')
        if missing_only:
            return commit
        if state == 'modified':
            raise RuntimeError(f'{path}: local changes; kept untouched. Inspect with git -C "{path}" diff and git -C "{path}" status before retrying.')
        git(path, 'fetch', '--depth=1', 'origin', 'HEAD')
        commit = git(path, 'rev-parse', 'FETCH_HEAD')
        git(path, 'checkout', '--detach', commit)
    else:
        # A failed first download must not leave a half-created destination.
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.' + path.name + '-', dir=path.parent) as temp:
            checkout = Path(temp) / 'checkout'
            result = sp.run(['git', 'clone', '--depth=1', url, str(checkout)], text=True, capture_output=True)
            if result.returncode:
                raise RuntimeError(f'{path.name}: clone failed: {result.stderr.strip()}')
            commit = git(checkout, 'rev-parse', 'HEAD')
            git(checkout, 'checkout', '--detach', commit)
            checkout.rename(path)
    return commit


def atomic_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', default='update', choices=['list', 'check', 'install', 'update'])
    parser.add_argument('names', nargs='*', help='Plugin names; default: all manifest plugins')
    parser.add_argument('--missing-only', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software'))))
    args = parser.parse_args(argv)
    specs = sources()
    names = args.names or list(specs)
    unknown = set(names) - specs.keys()
    if unknown:
        parser.error('Unknown plugin: ' + ', '.join(sorted(unknown)))
    root = args.prefix.expanduser().resolve()
    plugins = root / 'share/zsh/plugins'
    if args.action in ('list', 'check'):
        failed = False
        for name in names:
            state, commit = inspect(plugins / name)
            print(f'{name:26} {state:12} {commit[:12]}')
            failed |= state != 'installed'
        return int(failed and args.action == 'check')
    plugins.mkdir(parents=True, exist_ok=True)
    failures = []
    # Serialize simultaneous updates and retain receipts for unselected plugins.
    with (plugins.parent / '.plugins.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        record_path = plugins.parent / 'plugins-installed.json'
        records = json.loads(record_path.read_text()) if record_path.exists() else {}
        for name in names:
            try:
                commit = update(plugins / name, specs[name], args.missing_only or args.action == 'install')
                records[name] = dict(url=specs[name], commit=commit)
                atomic_json(record_path, records)
                print(f'{name}: OK {commit[:12]}', flush=True)
            except (RuntimeError, OSError) as error:
                failures.append(name)
                print(str(error), file=sys.stderr)
        completions = root / 'share/zsh/completions'
        completions.mkdir(parents=True, exist_ok=True)
        for name, options in [('pixi', ['completion', '--shell', 'zsh']), ('uv', ['generate-shell-completion', 'zsh'])]:
            exe = root / 'bin' / name
            executable = str(exe) if exe.exists() else shutil.which(name)
            if not executable:
                continue
            result = sp.run([executable, *options], text=True, capture_output=True)
            if result.returncode:
                failures.append(name + ' completion')
                print(f'{name}: completion failed (exit {result.returncode}); existing completion preserved. {result.stderr.strip()}', file=sys.stderr)
                continue
            temporary = completions / ('_' + name + '.tmp')
            temporary.write_text(result.stdout)
            temporary.replace(completions / ('_' + name))
    if failures:
        print('Failed: ' + ', '.join(failures) + '. Fix the reported cause and rerun workbench <plugin-name> update.', file=sys.stderr)
    return int(bool(failures))


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError) as error:
        print('plugins:', error, file=sys.stderr)
        sys.exit(1)
