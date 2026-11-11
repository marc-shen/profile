"""Platform detection is independent of installation and can be tested offline."""
import platform
from pathlib import Path

SUPPORTED = ('macos', 'steamdeck', 'fedora', 'ubuntu', 'debian')


def detect(system=None, release=None):
    system = system or platform.system()
    if system == 'Darwin':
        return 'macos'
    if system != 'Linux':
        raise RuntimeError('Unsupported operating system: ' + system)
    if release is None:
        release = Path('/etc/os-release').read_text()
    values = {}
    for line in release.splitlines():
        if '=' in line:
            key, value = line.split('=', 1)
            values[key] = value.strip('"\'')
    name = {'steamos': 'steamdeck'}.get(values.get('ID'), values.get('ID'))
    if name not in SUPPORTED:
        raise RuntimeError('Unsupported Linux distribution: ' + str(name))
    return name
