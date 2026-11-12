"""Bootstrap seed (Python 3.9+) and managed Python 3.12 provisioning.

Only this seed and software.manager run before the framework's Python 3.12 baseline.
"""
import json
import os
from pathlib import Path
import subprocess as sp
import sys
from software import manager, atomic_link, receipt


def usable(path, exact=False):
    if not os.access(path, os.X_OK): return False
    check = '== (3, 12)' if exact else '>= (3, 12)'
    return sp.run([str(path), '-I', '-c', 'import sys; sys.exit(not (sys.version_info[:2] ' + check + '))'],
                  stdout=sp.DEVNULL, stderr=sp.DEVNULL).returncode == 0


def expose(root, app, binary):
    # CPython resolves executable symlinks, but a symlinked parent directory can
    # leave its Linux exec_prefix at the build-time /install location.
    binary = binary.resolve()
    directory = app / 'bin'
    if directory.is_symlink(): directory.unlink()
    directory.mkdir(parents=True, exist_ok=True)
    for name in ('python', 'python3', 'python3.12'):
        atomic_link(binary, directory / name, root)
    atomic_link(app, root / 'apps/python/current', root)
    for name in ('python', 'python3', 'python3.12'):
        atomic_link(root / 'apps/python/current/bin' / name, root / 'bin' / name, root)


def ensure(root, offline=False, update=False):
    root = root.expanduser().resolve()
    executable = root / 'apps/python/current/bin/python3'
    if usable(executable, exact=True) and not update:
        expose(root, (root / 'apps/python/current').resolve(), executable.resolve())
        return executable
    if offline:
        if usable(Path(sys.executable)): return Path(sys.executable)
        raise RuntimeError('Python 3.12+ is required for offline bootstrap. Run bootstrap.sh online first.')
    uv = root / 'bin/uv'
    if not uv.is_file(): manager(root, 'uv')
    environment = dict(os.environ, UV_PYTHON_INSTALL_DIR=str(root / 'data/uv/python'),
                       UV_CACHE_DIR=str(root / 'cache/uv'))
    sp.run([uv, 'python', 'install', '3.12', '--no-bin', *(['--upgrade'] if update else [])], env=environment, check=True)
    binary = Path(sp.check_output([uv, 'python', 'find', '--managed-python', '--no-project', '--no-python-downloads', '3.12'],
                                 env=environment, text=True).strip())
    if not usable(binary, exact=True): raise RuntimeError('Managed Python 3.12 verification failed')
    version = sp.check_output([binary, '-I', '-c', 'import platform; print(platform.python_version())'], text=True).strip()
    app = root / 'apps/python' / version
    app.mkdir(parents=True, exist_ok=True)
    receipt(app, dict(name='python', version=version, backend='uv', runtime=str(binary)))
    expose(root, app, binary)
    return executable
