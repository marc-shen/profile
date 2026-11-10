"""Batch package installation follows the configured native runtime."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]

class PackageInstallerTests(unittest.TestCase):
    def test_unified_runtime_and_explicit_override_take_priority(self):
        with tempfile.TemporaryDirectory(prefix='package runtime ') as tmp:
            home = Path(tmp)
            root = home / 'Software'
            (root / 'bin').mkdir(parents=True)
            unified = home / 'Applications/Emacs Client.app/Contents/MacOS/Emacs'
            override = home / 'custom Emacs'
            log = home / 'calls'
            for binary in (unified, override, root / 'bin/emacs-real'):
                binary.parent.mkdir(parents=True, exist_ok=True)
                binary.write_text('#!/bin/bash\nprintf "%s\\n" "$0" "$@" > "$TEST_LOG"\n')
                binary.chmod(0o755)
            uname = root / 'bin/uname'
            uname.write_text('#!/bin/sh\necho Darwin\n')
            uname.chmod(0o755)
            env = dict(os.environ, HOME=str(home), SOFTWARE_HOME=str(root),
                       SOFTWARE_USER_HOME=str(root), TEST_LOG=str(log),
                       PATH=str(root / 'bin') + os.pathsep + os.defpath)
            env.pop('EMACS_BINARY', None)
            for chosen in (unified, override):
                if chosen == override: env['EMACS_BINARY'] = str(override)
                subprocess.run(['/bin/bash', str(SOURCE / 'scripts/install-emacs-packages.sh')],
                               env=env, check=True, capture_output=True, timeout=10)
                args = log.read_text().splitlines()
                self.assertEqual(args[0], str(chosen))
                self.assertEqual(args[1:4], ['--batch', '-Q', '-l'])
                self.assertEqual(args[4], str(SOURCE / 'platform/steamdeck/scripts/install-packages.el'))

if __name__ == '__main__': unittest.main()
