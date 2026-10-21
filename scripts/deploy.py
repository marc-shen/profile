#!/usr/bin/env python3
"""Reversible dotfile deployment. Does not install packages or restart a live Emacs."""
import argparse
import datetime
import os
from pathlib import Path
import plistlib
import shutil
import subprocess as sp
import sys

REPO = Path(__file__).resolve().parents[1]
HOME = Path.home()
ROOT = Path(os.environ.get('SOFTWARE_HOME', str(HOME / 'Software'))).absolute()
STAMP = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
BACKUP = ROOT / 'backups' / ('profile-' + STAMP)
DIRS = ['bin', 'apps', 'src', 'build', 'share/zsh/plugins', 'share/zsh/completions',
        'share/modulefiles', 'config/shell', 'config/local', 'config/modules',
        'config/systemd', 'scripts', 'cache/zsh', 'cache/pixi', 'cache/uv',
        'data', 'downloads/archives', 'downloads/installers', 'logs', 'backups', 'docs']
RUNTIME = ['.cache', 'elpa', 'eln-cache', 'var', 'tree-sitter', 'custom.el', 'projects.eld',
           'projects', 'tramp', 'auto-save-list', 'eshell', 'transient', 'log', 'agent', 'tramp-rpc']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('action', choices=['plan', 'link', 'check', 'service'])
parser.add_argument('--scope', choices=['user', 'system'], default='user')
parser.add_argument('--prefix', type=Path)
parser.add_argument('--dry-run', action='store_true')
parser.add_argument('--only', choices=['all', 'shell', 'emacs'], default='all')
args = parser.parse_args()
if args.prefix:
    ROOT = args.prefix.expanduser().absolute()
    BACKUP = ROOT / 'backups' / ('profile-' + STAMP)
DRY = args.dry_run or args.action == 'plan'

def exists(p): return p.exists() or p.is_symlink()
def save(p):
    if not exists(p): return
    relative = p.relative_to(HOME) if p.is_relative_to(HOME) else Path('external') / str(p).lstrip('/')
    target = BACKUP / relative
    print('backup', p, '->', target)
    if not DRY:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(p), str(target))
def link(src, dst):
    if not src.exists(): raise SystemExit(f'Missing deployment source: {src}')
    if exists(dst) and dst.resolve() == src.resolve(): return
    save(dst)
    print('link', dst, '->', src)
    if not DRY:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.symlink_to(src)
def write(dst, content, mode=0o644):
    if dst.is_file() and not dst.is_symlink() and dst.read_text() == content: return
    save(dst)
    print('write', dst)
    if not DRY:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(content)
        dst.chmod(mode)
def block(dst, content):
    start, end = '# >>> profile environment >>>', '# <<< profile environment <<<'
    old = dst.read_text() if dst.exists() else ''
    if start in old:
        before, rest = old.split(start, 1)
        _, after = rest.split(end, 1)
        old = before.rstrip() + '\n' + after.lstrip('\n')
    write(dst, old.rstrip() + '\n\n' + start + '\n' + content + '\n' + end + '\n')
def layout():
    for d in DIRS:
        if not DRY: (ROOT / d).mkdir(parents=True, exist_ok=True)
    link(REPO, ROOT / 'config/profile')
    link(REPO / 'scripts/software-app', ROOT / 'bin/software-app')
    link(REPO / 'docs/Software.txt', ROOT / 'README.txt')
    local_env = ROOT / 'config/local/env.sh'
    if not exists(local_env):
        old_uv = [HOME / '.local/share/uv', HOME / 'Library/Application Support/uv']
        if not any(p.exists() for p in old_uv):
            write(local_env, 'export UV_PYTHON_INSTALL_DIR="$SOFTWARE_HOME/data/uv/python"\n'
                  'export UV_TOOL_DIR="$SOFTWARE_HOME/data/uv/tools"\n'
                  'export UV_TOOL_BIN_DIR="$SOFTWARE_HOME/bin"\n', 0o600)

def emacs_config():
    dest = HOME / '.emacs.d'
    source = REPO / 'emacs.d'
    if dest.is_dir() and dest.resolve() != source.resolve():
        # Back up the original directory intact; copy local runtime only.
        for name in RUNTIME:
            old, new = dest / name, source / name
            if exists(old) and exists(new) and old.resolve() != new.resolve():
                raise SystemExit(f'Emacs runtime collision: {new}; reconcile before deployment (nothing deleted)')
        for name in RUNTIME:
            old, new = dest / name, source / name
            if exists(old) and not exists(new):
                print('preserve Emacs runtime', name)
                if not DRY:
                    if old.is_dir(): shutil.copytree(old, new, symlinks=True)
                    else: shutil.copy2(old, new)
    link(source, dest)
    for command in ['em', 'ec']:
        link(source / command, ROOT / 'bin' / command)
    link(REPO / 'scripts/emacs-daemon', ROOT / 'bin/emacs-daemon')
    mac_emacs = Path('/Applications/Emacs.app/Contents/MacOS/Emacs')
    if sys.platform == 'darwin' and mac_emacs.is_file():
        link(mac_emacs, ROOT / 'bin/emacs')
    os_release = Path('/etc/os-release')
    if os_release.exists() and any(line.startswith('ID=') and line.split('=', 1)[1].strip('"\'') == 'steamos' for line in os_release.read_text().splitlines()):
        for command in ['emacs', 'emacs-steam', 'deck-build']:
            link(REPO / 'platform/steamdeck/bin' / command, ROOT / 'bin' / command)
    # Retain Deck's existing Pixi-aware wrappers and the single X11 daemon.
    if not exists(ROOT / 'bin/emacsclient'):
        candidates = [Path('/Applications/Emacs.app/Contents/MacOS/bin/emacsclient'),
                      Path('/usr/bin/emacsclient')]
        candidates += sorted((ROOT / 'apps/emacs').glob('*/bin/emacsclient'), reverse=True)
        for candidate in candidates:
            if candidate.is_file():
                link(candidate, ROOT / 'bin/emacsclient'); break

def shell_config():
    link(REPO / 'zshrc', ROOT / 'config/shell/zshrc')
    link(REPO / 'shell/env.sh', ROOT / 'config/shell/env.sh')
    # Stable environment entry for Bash, Zsh, launchers and build scripts.
    import shlex
    write(ROOT / 'env.sh', 'export SOFTWARE_HOME=' + shlex.quote(str(ROOT)) + '\n. ' + shlex.quote(str(REPO / 'shell/env.sh')) + '\n. ' + shlex.quote(str(REPO / 'shell/modules.sh')) + '\n')
    link(REPO / 'zshrc', HOME / '.zshrc')
    # Preserve existing .zshenv content (e.g. Cargo) and local secrets in it.
    block(HOME / '.zshenv', 'export SOFTWARE_HOME=' + shlex.quote(str(ROOT)) + '\n. ' + shlex.quote(str(REPO / 'shell/env.sh')))
    if sys.platform == 'darwin':
        # macOS path_helper and brew shellenv run after .zshenv, including for
        # non-interactive login shells used by the native Emacs app launcher.
        block(HOME / '.zprofile', 'export SOFTWARE_HOME=' + shlex.quote(str(ROOT)) + '\n. ' + shlex.quote(str(REPO / 'shell/env.sh')))
    link(REPO / 'starship.toml', HOME / '.config/starship.toml')
    link(REPO / 'wezterm.lua', HOME / '.wezterm.lua')
    if args.only == 'all': link(REPO / 'nvim', HOME / '.config/nvim')
    modules = ROOT / 'apps/modules/current/init'
    if modules.is_dir(): link(modules, ROOT / 'config/modules/init')

def service():
    layout()
    link(REPO / 'scripts/emacs-daemon', ROOT / 'bin/emacs-daemon')
    if sys.platform == 'darwin':
        target = HOME / 'Library/LaunchAgents/org.gnu.emacs.daemon.plist'
        value = {'Label': 'org.gnu.emacs.daemon', 'ProgramArguments': [str(ROOT / 'bin/emacs-daemon')],
                 'EnvironmentVariables': {'SOFTWARE_HOME': str(ROOT)},
                 'RunAtLoad': True, 'KeepAlive': True, 'ProcessType': 'Interactive',
                 'LimitLoadToSessionType': 'Aqua', 'ThrottleInterval': 10}
        write(target, plistlib.dumps(value).decode())
        if not DRY:
            domain = f'gui/{os.getuid()}'
            active = sp.run(['launchctl', 'print', domain + '/org.gnu.emacs.daemon'], stdout=sp.DEVNULL, stderr=sp.DEVNULL).returncode == 0
            if not active: sp.run(['launchctl', 'bootstrap', domain, str(target)], check=True)
            else: print('Live daemon kept running; new service definition applies after logout/reload.')
    else:
        target = HOME / '.config/systemd/user/emacs.service'
        write(target, '[Unit]\nDescription=Personal Emacs daemon\n\n[Service]\nType=simple\nEnvironment="SOFTWARE_HOME=' + str(ROOT) + '"\nExecStart="' + str(ROOT / 'bin/emacs-daemon') + '"\nRestart=on-failure\nRestartSec=3\n\n[Install]\nWantedBy=default.target\n')
        if not DRY:
            sp.run(['systemctl', '--user', 'daemon-reload'], check=True)
            sp.run(['systemctl', '--user', 'enable', '--now', 'emacs.service'], check=True)

def check():
    missing = []
    for name in ['git', 'zsh', 'fd', 'rg', 'fzf', 'zoxide', 'starship', 'uv', 'pixi', 'emacsclient', 'software-app']:
        path = shutil.which(name, path=str(ROOT / 'bin') + os.pathsep + os.environ.get('PATH', ''))
        print(f'{name}: {path or "MISSING"}')
        if not path: missing.append(name)
    for name in ['fzf-tab', 'zsh-completions', 'zsh-autosuggestions', 'zsh-syntax-highlighting']:
        ok = (ROOT / 'share/zsh/plugins' / name).is_dir()
        print(f'{name}: {"OK" if ok else "MISSING"}')
        if not ok: missing.append(name)
    print('emacs.d ->', (HOME / '.emacs.d').resolve())
    print('Software:', ROOT)
    return bool(missing)

def shared_config():
    global REPO
    if args.action == 'service':
        raise SystemExit("Emacs services are per user. Run service from each user's personal profile checkout.")
    target = ROOT / 'config/profile'
    if target.exists() and target.resolve() != REPO.resolve():
        save(target)
    if not DRY and target.resolve() != REPO.resolve():
        shutil.copytree(REPO, target, symlinks=False,
                        ignore=shutil.ignore_patterns('.git', '__pycache__', '.DS_Store', *RUNTIME))
        for item in target.rglob('*'):
            if item.is_file() or item.is_dir(): item.chmod(item.stat().st_mode & ~0o022)
    REPO = target
    layout()
    import shlex
    write(ROOT / 'env.sh', 'export SOFTWARE_HOME=' + shlex.quote(str(ROOT)) + '\n. ' + shlex.quote(str(REPO / 'shell/env.sh')) + '\n')
    # Shells get command/module paths. Personal rc files and credentials are untouched.
    integration = '. ' + shlex.quote(str(ROOT / 'env.sh')) + '\n. ' + shlex.quote(str(REPO / 'shell/modules.sh'))
    if sys.platform == 'darwin':
        block(Path('/etc/zprofile'), integration)
    else:
        write(Path('/etc/profile.d/software.sh'), integration + '\n')
        zshenv = Path('/etc/zsh/zshenv') if Path('/etc/zsh').is_dir() else Path('/etc/zshenv')
        block(zshenv, integration)
    print('Shared tools installed; each user can link personal configuration separately.')

if args.scope == 'system' and args.action != 'check':
    shared_config()
    sys.exit(0)

if args.action == 'check': sys.exit(check())
if args.action == 'service': service()
else:
    # Emacs collision checks happen before shell replacement.
    if args.only in ['all', 'emacs']: emacs_config()
    layout()
    if args.only in ['all', 'shell']: shell_config()
    print('Review local settings in', ROOT / 'config/local/zshrc')
    print('Existing files are saved under', BACKUP)
    print('Service setup is separate: ./bootstrap.sh service')
