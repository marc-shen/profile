"""Exercise session-cookie rotation with real xauth in an isolated HOME."""
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1]/'scripts/emacs-x11-auth.sh'

@unittest.skipUnless(platform.system() == 'Linux' and shutil.which('xauth'), 'requires Linux xauth')
class XauthorityTests(unittest.TestCase):
    def test_rotating_session_preserves_other_displays_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)/'home with spaces'
            home.mkdir()
            source, target = home/'session authority', home/'.Xauthority'
            source.touch(mode=0o600)
            target.touch(mode=0o600)
            def auth(file, *args):
                return subprocess.check_output(['xauth', '-f', str(file), *args], text=True)
            auth(target, 'add', ':98', '.', '11'*16)
            env = dict(os.environ, HOME=str(home), DISPLAY=':99', XAUTHORITY=str(source))
            def sync():
                subprocess.run(['bash', '-euc', 'source "$1"', 'test', str(HELPER)], env=env, check=True)
            for cookie in ['22'*16, '33'*16]:
                auth(source, 'add', ':99', '.', cookie)
                sync()
                self.assertIn(cookie, auth(target, 'list', ':99'))
                self.assertIn('11'*16, auth(target, 'list', ':98'))
                self.assertEqual(target.stat().st_mode & 0o777, 0o600)
                before = target.read_bytes()
                sync()
                self.assertEqual(before, target.read_bytes())
            env['XAUTHORITY'] = str(target)
            sync()  # Avoid merging a file into itself.

    def test_plain_ssh_does_not_create_authority(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, HOME=tmp, DISPLAY='', XAUTHORITY='/missing-session')
            subprocess.run(['bash', '-euc', 'source "$1"', 'test', str(HELPER)], env=env, check=True)
            self.assertFalse((Path(tmp)/'.Xauthority').exists())

if __name__ == '__main__':
    unittest.main()
