#!/usr/bin/env python3
"""Read-only inventory and availability checks for Software components."""
import argparse
import json
import os
from pathlib import Path
import platform
import sys

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
from workbench.ui import Console


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('component', choices=['tools', 'managers', 'wezterm'])
    parser.add_argument('action', choices=['list', 'check'])
    parser.add_argument('names', nargs='*')
    args = parser.parse_args(argv)
    root = Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software')))
    if args.component == 'tools':
        specs = json.loads((REPO / 'catalog/tools.json').read_text())
    elif args.component == 'managers':
        specs = {name: {'commands': [name]} for name in ('pixi', 'uv')}
    else:
        specs = {'wezterm': {'commands': ['wezterm']}}
    if set(args.names) - specs.keys():
        parser.error('Unknown item: ' + ', '.join(sorted(set(args.names) - specs.keys())))
    failed = False
    rows = []
    for name in args.names or specs:
        commands = [root / 'bin' / command for command in specs[name]['commands']]
        if name == 'wezterm' and platform.system() == 'Darwin':
            commands = [Path('/Applications/WezTerm.app/Contents/MacOS/wezterm')]
        missing = [p.name for p in commands if not os.access(p, os.X_OK)]
        record = root / 'apps' / name / 'current/receipt.json'
        receipt = json.loads(record.read_text()) if record.is_file() else {}
        state = ('[MISSING] ' + ', '.join(missing)) if missing else '[OK]'
        rows.append((name, state + '  ' + str(receipt.get('version', '-')) + '\n' + str(commands[0])))
        failed |= bool(missing)
    Console().table(rows)
    return int(failed and args.action == 'check')


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
