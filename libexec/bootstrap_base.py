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
    legacy = root / 'bin/manage'
    if legacy.is_file() and MARKER in legacy.read_text(errors='replace'):
        backup(legacy, root)
        legacy.unlink()
    migrate_extensions(root)
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
            completion = '. ' + shlex.quote(str(repo / 'config/shell/completions/workbench.bash'))
            if completion not in value: value += '\n# workbench completion (Bash only)\n[ -z \"${BASH_VERSION:-}\" ] || ' + completion + '\n'
        write(path, value, root)


def install_missing_managers(root):
    from software import manager
    for name in ('pixi', 'uv'):
        if not os.access(root / 'bin' / name, os.X_OK):
            manager(root, name)


def migrate_extensions(root):
    """Import old local scripts without changing their argv or executable content."""
    import json
    old = root / 'config/manage.d'
    if not old.is_dir(): return
    for path in sorted(old.iterdir()):
        if not path.is_file() or not os.access(path, os.X_OK): continue
        name = path.stem if path.suffix in ('.py', '.sh') else path.name
        import re
        if not re.fullmatch('[a-z][a-z0-9-]*', name): continue
        destination = root / 'extensions' / name
        if destination.exists():
            raise RuntimeError('Extension migration collision: ' + str(destination))
        description, actions = 'Migrated local extension', []
        for line in path.read_text().splitlines()[:40]:
            if line.startswith('# manage-description:'): description = line.split(':', 1)[1].strip()
            if line.startswith('# manage-actions:'): actions = line.split(':', 1)[1].split()
        if not actions:
            raise RuntimeError('Declare manage-actions before migrating: ' + str(path))
        destination.mkdir(parents=True)
        shutil.copy2(path, destination / path.name)
        spec = dict(schema=1, name=name, description=description,
                    platforms=['macos','steamdeck','fedora','ubuntu','debian'],
                    entrypoint=['{module}/' + path.name],
                    actions={a:dict(description='Migrated ' + a) for a in actions})
        (destination / 'module.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n')
        backup(path, root); path.unlink()
    if not list(old.iterdir()): old.rmdir()
