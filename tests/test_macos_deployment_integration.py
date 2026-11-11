"""Opt-in real macOS packaging in a disposable HOME, without package installs.
Run with PROFILE_TEST_MACOS_DEPLOY=1 python3 -m unittest discover -s tests
-p 'test_macos_deployment_integration.py'. No live launch agent is started.
"""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import shutil
import unittest

SOURCE = Path(__file__).resolve().parents[1]

@unittest.skipUnless(sys.platform == 'darwin' and os.getenv('PROFILE_TEST_MACOS_DEPLOY') == '1',
                     'Opt-in macOS runtime packaging test')
class MacDeploymentTests(unittest.TestCase):
    def test_fresh_emacs_only_apply_and_repeat_preserve_runtime(self):
        with tempfile.TemporaryDirectory(prefix='profile mac install ') as tmp:
            home = Path(tmp).resolve()
            root = home / 'Software'
            checkout = home / 'checkout'
            checkout.mkdir()
            for name in ['bin','lib','libexec','components','platforms','catalog','profiles','config','docs']:
                shutil.copytree(SOURCE / name, checkout / name, symlinks=True,
                                ignore=shutil.ignore_patterns('__pycache__','elpa','eln-cache','var','tree-sitter','custom.el','projects.eld','projects','tramp','auto-save-list','eshell','transient','log','agent','tramp-rpc','.cache'))
            subprocess.run(['git','init','-q',str(checkout)],check=True)
            subprocess.run(['git','-C',str(checkout),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','--allow-empty','-qm','test'],check=True)

            env = dict(os.environ, HOME=str(home), SOFTWARE_HOME=str(root),
                       SOFTWARE_USER_HOME=str(root), WORKBENCH_HOME=str(checkout),
                       PYTHONDONTWRITEBYTECODE='1')
            def apply():
                result = subprocess.run([sys.executable, str(checkout / 'bin/workbench'),
                                         'profile', 'apply', '--only', 'emacs', '--config-only'],
                                        env=env, capture_output=True, text=True, timeout=120)
                self.assertIn(result.returncode, (0, 2), result.stdout + result.stderr)
                return result
            apply()
            app = home / 'Applications/Emacs Client.app'
            self.assertEqual((home / '.emacs.d').resolve(), checkout / 'config/emacs')
            self.assertTrue((home / '.emacs.d/lisp/init-restart.el').is_file())
            self.assertTrue((root / 'env.sh').is_file())
            self.assertFalse((home / '.zshrc').exists())
            slot = app / 'Contents/Runtime/Emacs.app'
            self.assertTrue(slot.is_symlink())
            self.assertEqual(slot.readlink(), Path('/Applications/Emacs.app'))
            for name in ('client-menu.dylib', 'dock-resident.dylib', 'prepare-runtime.py', 'activate-emacs'):
                self.assertTrue((app / 'Contents/Resources' / name).is_file())
            for command, relative in (('emacs', 'Emacs'), ('emacsclient', 'bin/emacsclient')):
                self.assertEqual((root / 'bin' / command).resolve(),
                                 app / 'Contents/MacOS' / relative)
            service = plistlib.loads((home / 'Library/LaunchAgents/org.gnu.emacs.daemon.plist').read_bytes())
            self.assertEqual(service['ProgramArguments'], [str(root / 'bin/emacs-daemon')])
            self.assertTrue(service['KeepAlive'])
            state = json.loads((root / 'data/profile/deployment.json').read_text())
            self.assertIn('config/emacs/lisp/init-restart.el', state['scopes']['emacs']['files'])
            service_step = next(step for step in state['last_attempt']['steps']
                                if 'service' in step['command'])
            self.assertIn('--no-start', service_step['command'])
            marker = app / 'Contents/Resources/profile-runtime.json'
            before = marker.stat().st_mtime_ns
            again = apply()
            self.assertEqual(marker.stat().st_mtime_ns, before)
            self.assertNotIn('deploy Dock application:', again.stdout)
            self.assertEqual(slot.readlink(), Path('/Applications/Emacs.app'))
            # A user's external runtime selection survives subsequent apply.
            external = home / 'Selected Runtime/Emacs.app'
            external.parent.mkdir()
            external.symlink_to('/Applications/Emacs.app')
            slot.unlink()
            slot.symlink_to(external)
            apply()
            self.assertEqual(slot.readlink(), external)
            self.assertEqual(json.loads(marker.read_text())['input'], str(external))

if __name__ == '__main__': unittest.main()
