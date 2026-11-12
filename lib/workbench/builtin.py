"""Adapters for existing installers; components declare the public contract."""
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
from .platforms import detect
from .ui import Console

REPO = Path(__file__).resolve().parents[2]
ROOT = Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software')))


def run(*args):
    return sp.run(list(map(str, args))).returncode


def backend(name, *args):
    return run(sys.executable, REPO / 'libexec' / name, *args)


def native_installed():
    if detect() == 'macos':
        return Path('/Applications/Emacs.app/Contents/MacOS/Emacs').is_file()
    return os.access(ROOT / 'apps/emacs/current/bin/emacs', os.X_OK) or bool(shutil.which('emacs'))


def main(name, argv):
    action, args = argv[0], argv[1:]
    platform = detect()
    if name in ('tools', 'managers', 'wezterm') and action in ('list', 'check'):
        return backend('component_inventory.py', name, action, *args)
    if name == 'plugins':
        return backend('plugins.py', action, *args)
    if name == 'languages':
        return backend('language-servers.py', {'list': 'plan', 'update': 'upgrade'}.get(action, action), *args)
    if name == 'managers':
        names = args or ['pixi', 'uv']
        if set(names) - {'pixi', 'uv'}:
            raise RuntimeError('Unknown manager')
        for item in names:
            if action == 'update' or not os.access(ROOT / 'bin' / item, os.X_OK):
                code = backend('software.py', 'managers', item)
                if code: return code
        return 0
    if name == 'tools':
        specs = json.loads((REPO / 'catalog/tools.json').read_text())
        names = [arg for arg in args if not arg.startswith('-')] or list(specs)
        if set(names) - specs.keys():
            raise RuntimeError('Unknown tool: ' + ', '.join(sorted(set(names) - specs.keys())))
        for item in names:
            if action == 'install' and all(os.access(ROOT / 'bin' / c, os.X_OK) for c in specs[item]['commands']):
                if specs[item].get('backend') != 'nvm': continue
                receipt = ROOT / 'apps/node/current/receipt.json'
                if receipt.is_file() and all(json.loads(receipt.read_text()).get(k) == specs[item][k] for k in ('backend', 'version', 'nvm_version')) and all((ROOT / 'bin' / c).resolve() == (ROOT / 'apps/node/current/bin' / c).resolve() for c in specs[item]['commands']): continue
            code = backend('software.py', 'tools', item, *[a for a in args if a.startswith('-')])
            if code: return code
        return 0
    if name == 'profile':
        if action == 'install':
            # Profile means configuration. Whole-machine installation lives in system.
            action = 'apply'
        if action == 'plan': return backend('profile_commands.py', 'apply', '--plan', *args)
        return backend('profile_commands.py', action, *args)
    if name == 'platform':
        from .provision import platform_action
        return platform_action(action, args, REPO, ROOT, platform)
    if name == 'emacs':
        from .provision import emacs_action
        return emacs_action(action, args, REPO, ROOT, platform)
    if name == 'network':
        if action == 'list': return backend('deck_network.py', 'list')
        targets = args or ['all']
        if set(targets) - {'all', 'sc302', 'mihomo', 'tailscale'}:
            raise RuntimeError('Network targets: all sc302 mihomo tailscale')
        if action == 'apply':
            sys.path.insert(0, str(REPO / 'libexec'))
            import deck_network
            services = deck_network.SERVICES if 'all' in targets else targets
            if not any(deck_network.service_pending(ROOT, service) for service in services):
                print('Network services already configured'); return 0
        for target in targets:
            code = backend('deck_network.py', target, {'install': 'prepare', 'apply': 'activate'}.get(action, action))
            if code: return code
        return 0
    if name == 'wezterm':
        if action == 'install' and (os.access(ROOT / 'bin/wezterm', os.X_OK) or (platform == 'macos' and Path('/Applications/WezTerm.app').is_dir())): return 0
        if platform == 'macos':
            return run('brew', 'upgrade' if action == 'update' else 'install', '--cask', 'wezterm')
        return backend('install-wezterm.py', *args)
    if name == 'components':
        from .scaffold import component_action
        return component_action(action, args, REPO, ROOT)
    if name == 'system':
        rows = []
        for path in sorted((REPO / 'profiles').glob('*.json')):
            spec = json.loads(path.read_text())
            rows.append((path.stem, spec['description'] + '\n' + ', '.join(spec['platforms'])))
        Console().table(rows)
        return 0
    if name == 'python-tools':
        sources = REPO / 'catalog/uv-tools.txt'
        names = args or [line.strip() for line in sources.read_text().splitlines() if line.strip() and not line.startswith('#')]
        if action == 'list':
            print('\n'.join(names)); return 0
        if action == 'check':
            result = sp.run([str(ROOT / 'bin/uv'), 'tool', 'list'], capture_output=True, text=True)
            if result.returncode: print(result.stderr); return result.returncode
            installed = {line.split()[0] for line in result.stdout.splitlines() if line and not line.startswith((' ', '-'))}
            missing = [name for name in names if name.split('[')[0] not in installed]
            for name in names: print(name + (': MISSING' if name in missing else ': installed'))
            return int(bool(missing))
        for item in names:
            code = run(ROOT / 'bin/uv', 'tool', 'install', *(['--upgrade'] if action == 'update' else []), item)
            if code: return code
        return 0
    raise RuntimeError('No adapter for ' + name)


def entry(name):
    try:
        return main(name, sys.argv[1:])
    except (RuntimeError, OSError, ValueError) as error:
        print(name + ': ' + str(error), file=sys.stderr)
        return 1
