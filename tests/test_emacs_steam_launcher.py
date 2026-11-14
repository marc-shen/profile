import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

LAUNCHER = Path(__file__).resolve().parents[1] / 'platforms/steamdeck/bin/emacs'


class SteamLauncherTests(unittest.TestCase):
    def invoke(self, args=(), app_id=None):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            root = home / 'Software'
            bin_dir = root / 'bin'
            bin_dir.mkdir(parents=True)
            (root / 'libexec').mkdir()
            (root / 'libexec/emacs-x11-auth.sh').write_text(':\n')
            (root / 'env.sh').write_text('export SOFTWARE_HOME="$HOME/Software"\n'
                                         'export WORKBENCH_HOME="$SOFTWARE_HOME"\n'
                                         'export PATH="$SOFTWARE_HOME/bin:$PATH"\n')
            for name in ('emacs-steam', 'emacsclient', 'emacs-x11'):
                path = bin_dir / name
                path.write_text('#!/usr/bin/env python3\nimport json,sys\n'
                                f'print(json.dumps([{name!r}, *sys.argv[1:]]))\n')
                path.chmod(0o755)
            path = bin_dir / 'systemctl'
            path.write_text('#!/bin/sh\nexit 0\n')
            path.chmod(0o755)
            env = dict(os.environ, HOME=str(home), DISPLAY=':1')
            env.pop('SteamAppId', None)
            if app_id is not None:
                env['SteamAppId'] = app_id
            result = subprocess.run(['bash', LAUNCHER, *args], env=env,
                                    capture_output=True, text=True, check=True)
            return json.loads(result.stdout)

    def test_desktop_shortcut_launched_by_steam_uses_tagged_client(self):
        self.assertEqual(self.invoke(app_id='3722122708'), ['emacs-steam'])
        self.assertEqual(self.invoke(['a file.md'], '3722122708'), ['emacs-steam', 'a file.md'])

    def test_desktop_and_terminal_invocations_keep_normal_behavior(self):
        self.assertEqual(self.invoke(['file.md'])[0], 'emacsclient')
        result = self.invoke(['-nw', 'file.md'], '3722122708')
        self.assertEqual(result[0], 'emacsclient')
        self.assertIn('--tty', result)

    def test_batch_is_never_redirected_to_a_steam_window(self):
        self.assertEqual(self.invoke(['--batch', '--version'], '3722122708'),
                         ['emacs-x11', '--batch', '--version'])


if __name__ == '__main__':
    unittest.main()
