"""Small, repeatable user bootstrap; no application/configuration deployment."""
import datetime
import os
from pathlib import Path
import shlex
import shutil
import sys

DIRECTORIES = ('bin', 'apps', 'src', 'build', 'config/local', 'extensions',
               'data', 'cache', 'logs', 'backups', 'downloads/archives', 'share/zsh/completions')
MARKER = '# Managed by profile bootstrap'


def backup(path, root):
    if not path.exists() and not path.is_symlink():
        return
    directory = root / 'backups' / ('bootstrap-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    directory.mkdir(parents=True)
    shutil.copy2(path, directory / path.name, follow_symlinks=False)


def write(path, value, root, mode=None):
    desired_mode = mode if mode is not None else ((path.stat().st_mode & 0o777) if path.exists() else 0o644)
    if path.is_file() and path.read_text() == value:
        if mode is not None: path.chmod(mode)
        return
    backup(path, root)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.new')
    temporary.write_text(value)
    temporary.chmod(desired_mode)
    temporary.replace(path)


def bash_completion(value, repo):
    """Replace our old completion block when the command or checkout moves."""
    lines = value.splitlines(keepends=True)
    kept, index = [], 0
    markers = {'# profilectl completion (Bash only)', '# workbench completion (Bash only)'}
    while index < len(lines):
        if lines[index].strip() in markers and index + 1 < len(lines):
            try:
                words = shlex.split(lines[index + 1])
            except ValueError:
                words = []
            if (len(words) == 7 and words[:6] == ['[', '-z', '${BASH_VERSION:-}', ']', '||', '.']
                    and words[-1].endswith(('/config/shell/completions/profilectl.bash',
                                           '/config/shell/completions/workbench.bash'))):
                index += 2
                continue
        kept.append(lines[index])
        index += 1
    completion = shlex.quote(str(repo / 'config/shell/completions/workbench.bash'))
    return (''.join(kept).rstrip() + '\n\n# workbench completion (Bash only)\n'
            '[ -z "${BASH_VERSION:-}" ] || . ' + completion + '\n')


def install(root, repo):
    from software import atomic_link
    entry = root / 'bin/workbench'
    if (entry.exists() or entry.is_symlink()) and (not entry.is_file() or MARKER not in entry.read_text(errors='replace')):
        raise RuntimeError(f'{entry} already exists and is not profile-managed; kept untouched.')
    for directory in DIRECTORIES:
        (root / directory).mkdir(parents=True, exist_ok=True)
    atomic_link(repo, root / 'config/workbench', root)
    write(entry, '#!/bin/sh\n' + MARKER + '\nexport SOFTWARE_HOME=' + shlex.quote(str(root)) + '\n'
          'exec ' + shlex.quote(sys.executable) + ' ' + shlex.quote(str(root / 'config/workbench/bin/workbench')) + ' "$@"\n', root, 0o755)
    # Retire only the wrapper we created; never remove an unrelated command.
    for name in ('manage', 'profilectl'):
        legacy = root / 'bin' / name
        if legacy.is_file() and MARKER in legacy.read_text(errors='replace'):
            backup(legacy, root)
            legacy.unlink()
    environment = root / 'env.sh'
    if environment.is_file():
        old = environment.read_text()
        value = old.replace('/shell/env.sh', '/config/shell/env.sh').replace('/shell/modules.sh', '/config/shell/modules.sh')
        value = value.replace('/config/config/shell/', '/config/shell/')
        if old != value: write(environment, value, root)
    if not environment.exists():
        write(environment, MARKER + '\nexport SOFTWARE_HOME=' + shlex.quote(str(root)) + '\n'
              '. ' + shlex.quote(str(root / 'config/workbench/config/shell/env.sh')) + '\n', root)
    start, end = '# >>> profile environment >>>', '# <<< profile environment <<<'
    content = 'export SOFTWARE_HOME=' + shlex.quote(str(root)) + '\n. ' + shlex.quote(str(root / 'config/workbench/config/shell/env.sh'))
    for filename in ('.profile', '.bashrc', '.zshenv', '.zprofile'):
        path = Path.home() / filename
        old = path.read_text() if path.exists() else ''
        if start in old:
            before, rest = old.split(start, 1)
            if end not in rest:
                raise RuntimeError(f'Incomplete profile environment block in {path}; kept untouched.')
            _, after = rest.split(end, 1)
            value = before + start + '\n' + content + '\n' + end + after
        else:
            value = old.rstrip() + '\n\n' + start + '\n' + content + '\n' + end + '\n'
        if filename == '.bashrc':
            value = bash_completion(value, repo)
        write(path, value, root)


def install_missing_managers(root):
    from software import manager
    for name in ('pixi', 'uv'):
        if not os.access(root / 'bin' / name, os.X_OK):
            manager(root, name)
