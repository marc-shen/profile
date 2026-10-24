#!/usr/bin/env python3
"""Apply a personal checkout, recording successful scopes independently of Git pull."""
import argparse
from contextlib import contextmanager
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys

REPO = Path(__file__).resolve().parents[1]
SCOPES = ('shell', 'emacs', 'helix')

def git(*args):
    return sp.check_output(['git', '-C', str(REPO), *args], text=True).strip()

def read_json(path, default):
    return json.loads(path.read_text()) if path.exists() else default

def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)

def snapshot():
    paths = sp.check_output(['git', '-C', str(REPO), 'ls-files', '-co', '--exclude-standard', '-z']).split(b'\0')
    result = {}
    for raw in paths:
        if not raw: continue
        name = os.fsdecode(raw)
        path = REPO / name
        if path.is_symlink(): payload = os.readlink(path).encode()
        elif path.is_file(): payload = path.read_bytes()
        else: continue
        result[name] = hashlib.sha256(payload + str(path.lstat().st_mode & 0o777).encode()).hexdigest()
    return result

def scope_files(files, scope):
    prefixes = {
        'shell': ('shell/', 'zshrc', 'starship.toml', 'wezterm.lua', 'manifests/zsh-plugins', 'manifests/tools'),
        'emacs': ('emacs.d/', 'platform/', 'manifests/language-servers', 'manifests/uv-tools'),
        'helix': ('helix/', 'manifests/language-servers'),
    }
    return {k: v for k, v in files.items() if k.startswith(('scripts/', 'bootstrap.sh') + prefixes[scope])}

def changed_files(old, new):
    return sorted(k for k in old.keys() | new.keys() if old.get(k) != new.get(k))

def executable(root, name):
    return shutil.which(name, path=str(root / 'bin') + os.pathsep + os.environ.get('PATH', os.defpath))

def missing_dependencies(root, scopes):
    missing = {'managers': [], 'tools': [], 'plugins': [], 'languages': [], 'native': []}
    for name in ('pixi', 'uv'):
        if not os.access(root / 'bin' / name, os.X_OK): missing['managers'].append(name)
    if 'shell' in scopes or 'helix' in scopes:
        for name, spec in read_json(REPO / 'manifests/tools.json', {}).items():
            if 'shell' not in scopes and name != 'helix': continue
            if any(not executable(root, c) for c in spec['commands']): missing['tools'].append(name)
    if 'shell' in scopes:
        for line in (REPO / 'manifests/zsh-plugins.sources').read_text().splitlines():
            if line.strip() and not line.startswith('#'):
                name = line.split()[0]
                if not (root / 'share/zsh/plugins' / name / '.git').exists(): missing['plugins'].append(name)
    if 'emacs' in scopes or 'helix' in scopes:
        for name, spec in read_json(REPO / 'manifests/language-servers.json', {}).items():
            if any(not executable(root, c) for c in spec['commands']): missing['languages'].append(name)
    if 'emacs' in scopes:
        if not executable(root, 'emacsclient'): missing['native'].append('Emacs (run bootstrap.sh install)')
    return missing

class Runner:
    def __init__(self, root, attempt):
        self.attempt = attempt
        self.path = root / 'logs' / ('profile-' + attempt['started_at'].replace(':', '-') + '.log')
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def run(self, name, args):
        args = list(map(str, args))
        print('->', name, flush=True)
        step = {'name': name, 'command': args, 'status': 'running'}
        self.attempt['steps'].append(step)
        with self.path.open('a') as log:
            log.write('\n' + name + '\n')
            process = sp.Popen(args, stdout=sp.PIPE, stderr=sp.STDOUT, text=True)
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
            code = process.wait()
        step.update(status='ok' if code == 0 else 'failed', returncode=code)
        if code: raise sp.CalledProcessError(code, args)

@contextmanager
def deployment_lock(root):
    path = root / 'data/profile/apply.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as handle:
        try: fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise RuntimeError('Another profile deployment is running.')
        yield

def verify_links(root, scopes):
    links = {root / 'config/profile': REPO}
    home = Path.home()
    if 'shell' in scopes:
        links.update({home / '.zshrc': REPO / 'zshrc', home / '.wezterm.lua': REPO / 'wezterm.lua'})
    if 'helix' in scopes or 'shell' in scopes: links[home / '.config/helix'] = REPO / 'helix'
    if 'emacs' in scopes:
        links[home / '.emacs.d'] = REPO / 'emacs.d'
        for command in ('em', 'ec', 'ediff'): links[root / 'bin' / command] = REPO / 'emacs.d' / command
    for target, source in links.items():
        if not target.is_symlink() or target.resolve() != source.resolve():
            raise RuntimeError('Incorrect deployment link: ' + str(target))
    return len(links)

def install_missing(root, scopes, runner):
    missing = missing_dependencies(root, scopes)
    for manager in missing['managers']:
        runner.run('install manager ' + manager, [sys.executable, REPO / 'scripts/software.py', 'managers', manager])
    if missing['tools']:
        runner.run('install missing tools', [sys.executable, REPO / 'scripts/software.py', 'tools', *missing['tools']])
    if missing['plugins']:
        runner.run('install missing plugins', [sys.executable, REPO / 'scripts/plugins.py', '--missing-only'])
    if missing['languages']:
        runner.run('install missing language servers', [sys.executable, REPO / 'scripts/language-servers.py', 'install', *missing['languages']])

def report_changes(scopes, state, files, root):
    changes = {}
    for scope in scopes:
        old = state.get('scopes', {}).get(scope, {}).get('files', {})
        changes[scope] = changed_files(old, scope_files(files, scope))
        print(f'{scope}: {len(changes[scope])} changed/new/removed files since last applied snapshot')
        for name in changes[scope][:12]: print('  ', name)
        if len(changes[scope]) > 12: print('  ...')
    for group, names in missing_dependencies(root, scopes).items():
        if names: print('Missing ' + group + ': ' + ', '.join(names))
    return changes

def apply_unlocked(args, root):
    scopes = list(SCOPES) if args.only == 'all' else [args.only]
    # Shell deployment also manages Helix, matching deploy.py's existing contract.
    if args.only == 'shell': scopes.append('helix')
    state_path = root / 'data/profile/deployment.json'
    state = read_json(state_path, {'schema': 1, 'scopes': {}})
    files = snapshot()
    changes = report_changes(scopes, state, files, root)
    if args.plan:
        print('PLAN: repair links, deploy the Mac Dock bundle, write service definitions without restarting Emacs, verify links.')
        print('Missing dependencies will ' + ('be installed.' if args.install_missing else 'be reported only.'))
        return 0
    attempt = {'started_at': datetime.datetime.now().astimezone().isoformat(timespec='microseconds'),
               'commit': git('rev-parse', 'HEAD'), 'dirty': bool(git('status', '--porcelain')),
               'scopes': scopes, 'steps': [], 'status': 'running'}
    runner = Runner(root, attempt)
    try:
        runner.run('deploy configuration', [sys.executable, REPO / 'scripts/deploy.py', 'link', '--prefix', root, '--only', args.only])
        if 'emacs' in scopes:
            runner.run('write Emacs service (keep live daemon)', [sys.executable, REPO / 'scripts/deploy.py', 'service', '--prefix', root, '--no-start'])
        if args.install_missing: install_missing(root, scopes, runner)
        print('Verified configuration links:', verify_links(root, scopes))
        pending = missing_dependencies(root, scopes)
        attempt['pending_dependencies'] = pending
        attempt['status'] = 'pending' if any(pending.values()) else 'ok'
        for scope in scopes:
            state.setdefault('scopes', {})[scope] = {'commit': attempt['commit'], 'dirty': attempt['dirty'],
                'files': scope_files(files, scope), 'applied_at': attempt['started_at']}
        if args.only == 'all' and attempt['status'] == 'ok':
            state['last_successful_commit'] = attempt['commit']
            state['last_successful_dirty'] = attempt['dirty']
        if changes.get('shell'): print('Reload: open a new terminal for updated shell configuration.')
        if changes.get('emacs'): print('Reload pending: save work and restart Emacs for Lisp/environment changes; no daemon was stopped. Service definition changes require service reload/logout.')
        if changes.get('helix'): print('Reload: restart Helix or use :config-reload.')
        if any(pending.values()):
            print('Configuration deployed; dependencies remain missing:', json.dumps(pending))
            print('Run bootstrap.sh apply --install-missing to install missing managed dependencies.')
        print('Deployment log:', runner.path)
        return 2 if attempt['status'] == 'pending' else 0
    except Exception as error:
        attempt.update(status='failed', error=str(error))
        raise
    finally:
        attempt['log'] = str(runner.path)
        state.update(repo=str(REPO), last_attempt=attempt)
        atomic_json(state_path, state)

def apply(args, root):
    if args.plan:
        return apply_unlocked(args, root)
    with deployment_lock(root):
        return apply_unlocked(args, root)


def upgrade(args, root):
    if args.tool and args.component not in ('tools', 'languages'):
        raise RuntimeError('--tool is only supported for tools/languages upgrades.')
    component = args.component
    if args.tool:
        manifest = 'tools.json' if component == 'tools' else 'language-servers.json'
        unknown = set(args.tool) - read_json(REPO / 'manifests' / manifest, {}).keys()
        if unknown: raise RuntimeError('Unknown upgrade selection: ' + ', '.join(sorted(unknown)))
    commands = []
    if component == 'all': commands.append(('upgrade platform and Emacs', ['bash', REPO / 'scripts/install-platform.sh', 'update']))
    if component == 'tools': commands.append(('upgrade tools', [sys.executable, REPO / 'scripts/software.py', 'tools', *args.tool]))
    if component == 'managers': commands.append(('upgrade managers', [sys.executable, REPO / 'scripts/software.py', 'managers']))
    if component == 'plugins': commands.append(('upgrade plugins', [sys.executable, REPO / 'scripts/plugins.py']))
    if component in ('all', 'languages'): commands.append(('upgrade language servers', [sys.executable, REPO / 'scripts/language-servers.py', 'upgrade', *args.tool]))
    if component == 'emacs':
        if sys.platform == 'darwin': commands.append(('upgrade Emacs', ['brew', 'upgrade', '--cask', 'emacs-app']))
        else:
            deck = Path('/etc/os-release').exists() and any(line.startswith('ID=') and line.split('=', 1)[1].strip('"\'') == 'steamos' for line in Path('/etc/os-release').read_text().splitlines())
            commands.append(('build Emacs', [sys.executable, REPO / 'scripts/build-emacs.py', '--deps', 'pixi' if deck else 'system']))
    if args.plan:
        for label, command in commands: print('PLAN:', label, list(map(str, command)))
        return 0
    with deployment_lock(root):
        attempt = {'started_at': datetime.datetime.now().astimezone().isoformat(timespec='microseconds'), 'steps': []}
        runner = Runner(root, attempt)
        for label, command in commands: runner.run(label, command)
    print('Upgrade complete. Run bootstrap.sh apply for configuration deployment.')
    return 0

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['apply', 'sync', 'upgrade'])
    parser.add_argument('--prefix', type=Path, required=True)
    parser.add_argument('--only', choices=['all', *SCOPES], default='all')
    parser.add_argument('--plan', action='store_true')
    parser.add_argument('--install-missing', action='store_true')
    parser.add_argument('--component', choices=['tools', 'managers', 'plugins', 'languages', 'emacs', 'all'], default='tools')
    parser.add_argument('--tool', action='append', default=[])
    args = parser.parse_args()
    root = args.prefix.expanduser().absolute()
    os.environ['SOFTWARE_HOME'] = str(root)
    os.environ['PATH'] = str(root / 'bin') + os.pathsep + os.environ.get('PATH', os.defpath)
    os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
    if args.action == 'sync':
        if git('status', '--porcelain'):
            raise RuntimeError('Checkout has local changes. Commit or back them up before sync; no auto-stash/reset is performed.')
        if args.plan:
            print('PLAN: git pull --ff-only, then apply the newly pulled scripts. No fetch performed in preview.')
            return apply(args, root)
        git('rev-parse', '--abbrev-ref', '@{upstream}')
        with deployment_lock(root):
            sp.run(['git', '-C', str(REPO), 'pull', '--ff-only'], check=True)
        # Execute the UPDATED entry point, not this pre-pull Python module.
        command = ['bash', str(REPO / 'bootstrap.sh'), 'apply', '--prefix', str(root), '--only', args.only]
        if args.install_missing: command.append('--install-missing')
        os.execvp('bash', command)
    return upgrade(args, root) if args.action == 'upgrade' else apply(args, root)

if __name__ == '__main__':
    try: sys.exit(main())
    except (RuntimeError, sp.CalledProcessError) as error:
        print('profile:', error, file=sys.stderr)
        sys.exit(1)
