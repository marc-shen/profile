#!/usr/bin/env python3
"""Create Software, install workbench, and prepare the minimal package managers."""
import argparse
import os
from pathlib import Path
import shutil
import sys

from bootstrap_base import install, install_missing_managers

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(prog='bootstrap.sh', description=__doc__,
        epilog='Daily work: workbench profile apply / update; workbench tools update; workbench list.')
    parser.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software'))))
    parser.add_argument('--offline', action='store_true', help='Create layout and workbench only; skip missing uv/pixi downloads')
    parser.add_argument('--plan', action='store_true', help='Show bootstrap steps without writes or downloads')
    args = parser.parse_args()
    # Canonicalize parent aliases (e.g. macOS /var -> /private/var) before
    # creating relative links inside the installation.
    root = args.prefix.expanduser().resolve()
    if args.plan:
        print('Software:', root)
        print('Create directories, link this checkout, install workbench, wire shell PATH/environment.')
        print('Missing uv/pixi: ' + ('leave for later (offline).' if args.offline else 'install official binaries; preserve installed versions.'))
        print('No applications, editor configs, proxy settings or services will be deployed.')
        return 0
    if os.geteuid() == 0:
        raise RuntimeError('Run bootstrap as your regular user, not root.')
    for name in ('git', 'curl'):
        if not shutil.which(name):
            raise RuntimeError('Install prerequisite first: ' + name)
    os.environ['SOFTWARE_HOME'] = str(root)
    install(root, REPO)
    if not args.offline:
        install_missing_managers(root)
    print('Base environment ready:', root)
    print('For this terminal: . ' + str(root / 'env.sh'))
    print('Next: workbench list; workbench profile apply')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError) as error:
        print('bootstrap:', error, file=sys.stderr)
        sys.exit(1)
