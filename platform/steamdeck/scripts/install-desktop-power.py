#!/usr/bin/env python3
"""Persist the Steam Deck desktop AC sleep preference in the user's home."""
import datetime
import os
from pathlib import Path
import shutil
import subprocess as sp

if not Path('/etc/os-release').exists() or 'ID=steamos' not in Path('/etc/os-release').read_text():
    raise SystemExit('This installer is for SteamOS desktop mode.')
home = Path.home()
root = Path(os.environ.get('SOFTWARE_USER_HOME', str(home/'Software'))).expanduser().resolve()
config = Path(os.environ.get('XDG_CONFIG_HOME', str(home/'.config')))
script = root/'scripts/desktop-ac-awake.sh'
dropin = config/'systemd/user/plasma-powerdevil.service.d/90-profile-ac-awake.conf'
backup = root/'backups'/('desktop-power-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
for path in [config/'powerdevilrc', script, dropin]:
    if path.exists():
        dest = backup/path.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
script.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(Path(__file__).with_name('desktop-ac-awake.sh'), script)
script.chmod(0o755)
# systemd performs its own percent expansion even inside quoted arguments.
argument = str(script).replace('%', '%%').replace('\\', '\\\\').replace('"', '\\"')
dropin.parent.mkdir(parents=True, exist_ok=True)
dropin.write_text('[Service]\n# Reapply the user preference before each desktop power service start.\n'
                 '# A future missing helper must not prevent battery power management starting.\n'
                 'ExecStartPre=-/bin/bash "'+argument+'"\n')
sp.run(['/bin/bash', str(script)], check=True)
sp.run(['systemctl', '--user', 'daemon-reload'], check=True)
if sp.run(['systemctl', '--user', 'is-active', '--quiet', 'plasma-powerdevil.service']).returncode == 0:
    sp.run(['/usr/bin/qdbus6', 'org.kde.Solid.PowerManagement', '/org/kde/Solid/PowerManagement',
            'org.kde.Solid.PowerManagement.reparseConfiguration'], check=True)
print('Desktop automatic suspend on AC: disabled')
print('Persistent startup rule:', dropin)
print('Backups:', backup)
