#!/usr/bin/env python3
"""Portable installation entry point; package sources are explicit and recorded."""
import argparse, os, platform, shutil, subprocess as sp, sys
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('action',choices=['plan','install','update','link','check','service','apply','sync','upgrade'],nargs='?',default='plan')
p.add_argument('--scope',choices=['user','system'],default='user')
p.add_argument('--prefix',type=Path)
p.add_argument('--dry-run',action='store_true')
p.add_argument('--only',choices=['all','shell','emacs','helix'],default='all')
p.add_argument('--reinstall',action='store_true')
p.add_argument('--plan',action='store_true',help='Preview apply/sync/upgrade without network or writes')
p.add_argument('--install-missing',action='store_true',help='Install missing tools, plugins and language servers during apply/sync')
p.add_argument('--component',choices=['tools','managers','plugins','languages','emacs','all'],default='tools')
p.add_argument('--tool',action='append',default=[],help='Select a tool/language-server for upgrade; repeatable')
a=p.parse_args();root=(a.prefix or Path('/opt/Software' if a.scope=='system' else os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software')))).expanduser().absolute()
os.environ['SOFTWARE_HOME']=str(root)
def run(args):sp.run(list(map(str,args)),check=True)
if a.action in ['apply','sync','upgrade']:
 if a.scope!='user':sys.exit('apply/sync/upgrade currently support per-user deployments only; shared /opt provisioning remains separate.')
 if os.geteuid()==0:sys.exit('Run personal deployment as the target user, not root.')
 command=[sys.executable,'-B',str(repo/'scripts/profile-sync.py'),a.action,'--prefix',str(root),'--only',a.only,'--component',a.component]
 if a.plan or a.dry_run:command+=['--plan']
 if a.install_missing:command+=['--install-missing']
 for name in a.tool:command+=['--tool',name]
 os.execv(sys.executable,command)
if a.plan:a.dry_run=True
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
