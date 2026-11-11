#!/usr/bin/env python3
"""Refresh user-owned links to installed Intel modulefiles; no changes under /opt."""
from pathlib import Path
import datetime
import os
import shutil

root = Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software')))
intel = Path('/opt/intel/oneapi')
target = root / 'share/modulefiles/intel'
if not intel.is_dir(): raise SystemExit('Intel oneAPI is not installed under /opt/intel/oneapi')
backup = root / 'backups' / ('intel-modules-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
if target.exists():
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(target, backup, symlinks=True)
target.mkdir(parents=True, exist_ok=True)
for p in target.rglob('*'):
    if p.is_symlink() and not p.exists(): p.unlink()
count = 0
for source in sorted(intel.glob('*/*/etc/modulefiles/*/*')):
    if not source.is_file() or source.name.startswith('.'): continue
    dest = target / source.parent.name / source.name
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink(): dest.unlink()
    elif dest.exists():
        print('Kept custom file:', dest); continue
    dest.symlink_to(source.resolve()); count += 1
for source in sorted(intel.glob('*/latest/etc/modulefiles/*/*')):
    if not source.is_file() or source.name.startswith('.'): continue
    dest = target / source.parent.name / 'latest'
    if dest.is_symlink(): dest.unlink()
    elif dest.exists(): continue
    dest.symlink_to(source.resolve())
print(f'Refreshed Intel module links ({count} entries scanned); backup: {backup}')
