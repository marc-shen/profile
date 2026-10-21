#!/usr/bin/env python3
"""Portable installation entry point; package sources are explicit and recorded."""
import argparse, os, platform, shutil, subprocess as sp, sys
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('action',choices=['plan','install','update','link','check','service'],nargs='?',default='plan')
p.add_argument('--scope',choices=['user','system'],default='user')
p.add_argument('--prefix',type=Path)
p.add_argument('--dry-run',action='store_true')
p.add_argument('--only',choices=['all','shell','emacs'],default='all')
p.add_argument('--reinstall',action='store_true')
a=p.parse_args();root=(a.prefix or Path('/opt/Software' if a.scope=='system' else os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software')))).expanduser().absolute()
os.environ['SOFTWARE_HOME']=str(root)
def run(args):sp.run(list(map(str,args)),check=True)
if a.action=='plan' or a.dry_run:
 print('Platform:',platform.system(),platform.machine());print('Scope:',a.scope,'Prefix:',root)
 print('System Git; upstream Pixi/uv; isolated Pixi CLI tools; upstream Git Zsh plugins.')
 print('Emacs: Homebrew on macOS; source on Linux. Configuration/data remain per user.')
 print('Explicit updates; retain installation receipts and locks. No automatic package-manager fallback on errors.')
 sys.exit(0)
if a.scope=='system' and os.geteuid()!=0:sys.exit('System provisioning requires an administrator. Run this command with sudo.')
if a.scope=='user' and os.geteuid()==0:sys.exit('Do not deploy personal dotfiles as root; use --scope system or the target user.')
if a.scope=='system' and Path('/etc/os-release').exists() and any(line.strip().strip('"\'')=='steamos' for line in [entry.split('=',1)[1] for entry in Path('/etc/os-release').read_text().splitlines() if entry.startswith('ID=')]):
 sys.exit('SteamOS stays read-only: use a user installation under ~/Software.')
if a.action in ['install','update']:
 run(['bash',repo/'scripts/install-platform.sh',a.action,*(['--reinstall'] if a.reinstall else [])])
 action='link'
else:action=a.action
run([sys.executable,repo/'scripts/deploy.py',action,'--scope',a.scope,'--prefix',root,'--only',a.only])
