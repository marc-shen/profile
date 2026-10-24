#!/usr/bin/env python3
"""Portable installation entry point; package sources are explicit and recorded."""
import argparse, os, platform, shutil, subprocess as sp, sys
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
simple=len(sys.argv)>1 and sys.argv[1] in ['apply','sync']
p=argparse.ArgumentParser(prog='bootstrap.sh',description=__doc__)
if simple:
 p.add_argument('action',choices=[sys.argv[1]])
else:
 p.add_argument('action',choices=['plan','install','update','link','check','service','apply','sync','upgrade'],nargs='?',default='plan')
if simple:
 p.description='Sync pulls Git then applies; apply deploys the current checkout. Both install missing dependencies and verify language servers by default.'
p.add_argument('--scope',choices=['user','system'],default='user',help=argparse.SUPPRESS if simple else 'Installation scope')
p.add_argument('--prefix',type=Path,help=argparse.SUPPRESS if simple else 'Software installation directory')
p.add_argument('--dry-run',action='store_true',help=argparse.SUPPRESS)
p.add_argument('--only',choices=['all','shell','emacs','helix'],default='all',help='Deploy only this configuration group (default: all)')
p.add_argument('--reinstall',action='store_true',help=argparse.SUPPRESS if simple else 'Reinstall Pixi tools during install/update')
p.add_argument('--plan',action='store_true',help='Preview without network or writes')
p.add_argument('--config-only',dest='install_missing',action='store_false',help='Deploy configuration only; skip dependency installation and LSP probes')
p.set_defaults(install_missing=True)
p.add_argument('--component',choices=['tools','managers','plugins','languages','emacs','all'],default='tools',help=argparse.SUPPRESS if simple else 'Upgrade component (default: tools)')
p.add_argument('--tool',action='append',default=[],help=argparse.SUPPRESS if simple else 'Select a tool/language-server for upgrade; repeatable')
a=p.parse_args();root=(a.prefix or Path('/opt/Software' if a.scope=='system' else os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software')))).expanduser().absolute()
os.environ['SOFTWARE_HOME']=str(root)
def run(args):sp.run(list(map(str,args)),check=True)
if a.action in ['apply','sync','upgrade']:
 if a.scope!='user':sys.exit('apply/sync/upgrade currently support per-user deployments only; shared /opt provisioning remains separate.')
 if os.geteuid()==0:sys.exit('Run personal deployment as the target user, not root.')
 command=[sys.executable,'-B',str(repo/'scripts/profile-sync.py'),a.action,'--prefix',str(root),'--only',a.only,'--component',a.component]
 if a.plan or a.dry_run:command+=['--plan']
 if not a.install_missing:command+=['--config-only']
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
