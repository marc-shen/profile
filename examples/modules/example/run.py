#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
name = json.loads((Path(__file__).resolve().parent / 'module.json').read_text())['name']
target = Path(os.environ['SOFTWARE_HOME']) / 'data/extensions' / name / 'example.txt'
action = sys.argv[1]
if action == 'list':
    print(str(target) + (' [installed]' if target.exists() else ' [missing]'))
elif action == 'check':
    print('OK' if target.is_file() else 'MISSING')
    raise SystemExit(0 if target.is_file() else 1)
elif action in ('install', 'update'):
    if action == 'update' or not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('Managed by ' + name + '\n')
else:
    raise SystemExit('Unsupported action: ' + action)
