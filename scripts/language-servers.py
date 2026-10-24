#!/usr/bin/env python3
"""Install missing Eglot tools or explicitly upgrade them, using upstream uv/Pixi."""
import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
import software
from lsp_probe import probe

REPO = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'install', 'upgrade', 'check'])
    parser.add_argument('names', nargs='*')
    parser.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software'))))
    parser.add_argument('--probe', action='store_true', help='Verify real LSP initialize/shutdown, without opening an editor')
    args = parser.parse_args()
    root = args.prefix.expanduser().absolute()
    os.environ['SOFTWARE_HOME'] = str(root)
    os.environ['PATH'] = str(root / 'bin') + os.pathsep + os.environ.get('PATH', os.defpath)
    for variable, relative in [('UV_TOOL_DIR', 'data/uv/tools'), ('UV_TOOL_BIN_DIR', 'bin'),
                               ('UV_PYTHON_INSTALL_DIR', 'data/uv/python'), ('UV_CACHE_DIR', 'cache/uv'),
                               ('PIXI_CACHE_DIR', 'cache/pixi')]:
        os.environ.setdefault(variable, str(root / relative))
    specs = json.loads((REPO / 'manifests/language-servers.json').read_text())
    names = args.names or list(specs)
    unknown = set(names) - specs.keys()
    if unknown: parser.error('Unknown language server: ' + ', '.join(sorted(unknown)))
    records_path = root / 'data/profile/language-servers.json'
    records = json.loads(records_path.read_text()) if records_path.exists() else {}
    failed = []
    for name in names:
        spec = specs[name]
        available = all(shutil.which(c) for c in spec['commands'])
        print(name + ': ' + ('available' if available else 'MISSING') + ' (' + spec['backend'] + ': ' + spec['package'] + ')', flush=True)
        if args.action == 'plan': continue
        if args.action == 'check' and not available:
            failed.append(name); continue
        installed = False
        if args.action == 'upgrade' or (args.action == 'install' and not available):
            manager = root / 'bin' / spec['backend']
            if not os.access(manager, os.X_OK):
                raise RuntimeError(str(manager) + ' missing; run bootstrap.sh apply --install-missing first.')
            if spec['backend'] == 'uv':
                command = [str(manager), 'tool', 'install', spec['package']]
                if args.action == 'upgrade': command.append('--upgrade')
                sp.run(command, check=True)
            else:
                software.tool(root, 'lsp-' + name, spec)
            installed = True
        if installed or args.probe:
            command = [shutil.which(spec['lsp'][0]), *spec['lsp'][1:]]
            if not command[0]: raise RuntimeError('Missing command after installation: ' + spec['lsp'][0])
            info = probe(command)
            print(name + ': LSP initialize/shutdown OK', flush=True)
            if args.action != 'check':
                records[name] = dict(package=spec['package'], backend=spec['backend'], command=command,
                                     server_info=info, verified_at=datetime.datetime.now().astimezone().isoformat())
                if spec.get('version'):
                    records[name]['version'] = sp.check_output(spec['version'], text=True).strip()
                records_path.parent.mkdir(parents=True, exist_ok=True)
                with records_path.with_suffix('.lock').open('a') as lock:
                    fcntl.flock(lock, fcntl.LOCK_EX)
                    latest = json.loads(records_path.read_text()) if records_path.exists() else {}
                    latest[name] = records[name]
                    temporary = records_path.with_suffix('.tmp')
                    temporary.write_text(json.dumps(latest, ensure_ascii=False, indent=2) + '\n')
                    temporary.replace(records_path)
    return bool(failed)

if __name__ == '__main__':
    try: sys.exit(main())
    except (RuntimeError, sp.CalledProcessError) as error:
        print(error, file=sys.stderr); sys.exit(1)
