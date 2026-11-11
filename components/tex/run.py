#!/usr/bin/env python3
import json, os, subprocess, sys
from pathlib import Path
root = Path(os.environ['SOFTWARE_HOME'])
action = sys.argv[1]
command = root / 'bin/xelatex'
receipt = root / 'apps/texlive/current/receipt.json'
if action == 'list':
 print(receipt.read_text() if receipt.is_file() else 'texlive: not installed')
 raise SystemExit(0)
if action == 'check':
 if not os.access(command, os.X_OK): raise SystemExit('Missing: ' + str(command))
 raise SystemExit(subprocess.run([str(command), '--version']).returncode)
if action == 'install' and os.access(command, os.X_OK) and receipt.is_file():
 raise SystemExit(0)
raise SystemExit(subprocess.run([os.environ['PROFILE_PYTHON'], str(Path(os.environ['WORKBENCH_HOME']) / 'libexec/install-texlive.py'), *sys.argv[2:]]).returncode)
