"""Share SteamOS CA trust with the Steam client container without root writes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

SOURCE = Path(__file__).resolve().parents[1] / 'platforms/steamdeck/bin/steam-ca-bwrap'
CA_BUNDLE = Path('/etc/ssl/certs/ca-certificates.crt')


def bridge_paths(root):
    return (root / 'libexec/steam-ca-bwrap',
            Path.home() / '.config/systemd/user/steam-launcher.service.d/60-workbench-ca.conf')


def unit_text(hook):
    setting = 'PRESSURE_VESSEL_BWRAP=' + str(hook).replace('%', '%%')
    return '[Service]\nEnvironment=' + json.dumps(setting) + '\n'


def install(root):
    from deck_network import write
    hook, unit = bridge_paths(root)
    write(hook, SOURCE.read_text(), 0o755)
    write(unit, unit_text(hook))
    subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
    print('Steam CA bridge installed; restart Steam to use current system CA trust.')


def check(root, proc=Path('/proc'), ca=CA_BUNDLE):
    """Check deployment and, when Steam is running, the actual container CA."""
    hook, unit = bridge_paths(root)
    try:
        if (hook.read_text() != SOURCE.read_text() or not os.access(hook, os.X_OK)
                or unit.read_text() != unit_text(hook)):
            raise ValueError('outdated bridge')
    except (OSError, ValueError):
        return ['Steam CA bridge: workbench steamcommunity302 install, then restart Steam']
    try:
        expected = hashlib.sha256(ca.read_bytes()).digest()
    except OSError:
        return ['Steam CA bridge: system CA bundle is unavailable']
    for directory in proc.glob('[0-9]*'):
        try:
            if directory.stat().st_uid != os.getuid() or (directory / 'comm').read_text().strip() != 'steam':
                continue
            container = directory / 'root'
            if not (container / 'run/pressure-vessel').exists():
                continue
            actual = (container / 'etc/ssl/certs/ca-certificates.crt').read_bytes()
        except FileNotFoundError:
            if (directory / 'root/run/pressure-vessel').exists():
                return ['Steam CA bridge: running Steam container has no CA bundle']
            continue  # Process exited while being inspected.
        except PermissionError:
            return ['Steam CA bridge: cannot inspect the running Steam container']
        if hashlib.sha256(actual).digest() != expected:
            return ['Steam CA bridge: restart Steam to load the current system CA bundle']
    return []
