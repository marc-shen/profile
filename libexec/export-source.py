#!/usr/bin/env python3
"""Export installable source without Git history, runtime data or local compatibility aliases."""
import argparse
from pathlib import Path
import subprocess
import tarfile
REPO = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args = parser.parse_args()
allowed = {'bin','lib','libexec','commands','providers','components','profiles','platforms','config','catalog','examples','docs','tests','archive','README.md','README.txt','bootstrap.sh','install.sh','.gitignore','modulefile.md'}
files = set(subprocess.check_output(['git','-C',str(REPO),'ls-files','-co','--exclude-standard','-z']).decode().split('\0'))
selected=[]
for name in sorted(files):
    if not name or name.split('/')[0] not in allowed: continue
    path=REPO/name
    if not path.is_file() or any(p.is_symlink() for p in path.parents if p!=REPO and REPO in p.parents): continue
    selected.append(name)
with tarfile.open(args.output,'w:gz') as archive:
    for name in selected: archive.add(REPO/name,arcname=name,recursive=False)
print('Exported',len(selected),'source files to',args.output)
