"""Exercise data preservation and idempotency in an isolated HOME and checkout."""
import os
from pathlib import Path
import shutil
import subprocess as sp
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]

class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name).resolve()
        self.home = self.base / 'home with spaces'
        self.home.mkdir()
        self.repo = self.base / 'repo with spaces'
        self.repo.mkdir()
        for name in ['scripts', 'shell', 'docs', 'nvim']:
            shutil.copytree(SOURCE / name, self.repo / name)
        for name in ['zshrc', 'starship.toml', 'wezterm.lua']:
            shutil.copy2(SOURCE / name, self.repo / name)
        (self.repo / 'emacs.d').mkdir()
        for name in ['em', 'ec', 'init.el']:
            shutil.copy2(SOURCE / 'emacs.d' / name, self.repo / 'emacs.d' / name)
        self.env = dict(os.environ, HOME=str(self.home), SOFTWARE_HOME=str(self.home / 'Software'))
    def tearDown(self): self.tmp.cleanup()
    def run_deploy(self, *args, check=True):
        return sp.run(['python3', str(self.repo / 'scripts/deploy.py'), *args], env=self.env,
                      capture_output=True, text=True, check=check)
    def test_plan_has_no_side_effects(self):
        (self.home / '.zshrc').write_text('private local preference\n')
        self.run_deploy('plan')
        self.assertEqual(list(self.home.iterdir()), [self.home / '.zshrc'])
    def test_backup_idempotency_and_whole_emacs_directory(self):
        (self.home / '.zshrc').write_text('private local preference\n')
        (self.home / '.zshenv').write_text('export KEEP_ME=yes\n')
        runtime = self.home / '.emacs.d/var'
        runtime.mkdir(parents=True)
        (runtime / 'history').write_text('keep session data')
        self.run_deploy('link')
        self.assertEqual((self.home / '.emacs.d').resolve(), self.repo / 'emacs.d')
        self.assertEqual((self.home / '.emacs.d/var/history').read_text(), 'keep session data')
        backup = list((self.home / 'Software/backups').glob('profile-*'))
        self.assertEqual(len(backup), 1)
        self.assertEqual((backup[0] / '.zshrc').read_text(), 'private local preference\n')
        self.assertIn('export KEEP_ME=yes', (self.home / '.zshenv').read_text())
        self.run_deploy('link')
        self.assertEqual(backup, list((self.home / 'Software/backups').glob('profile-*')))
    def test_conflicting_runtime_refuses_without_replacing_shell(self):
        for p in [self.home / '.emacs.d/var', self.repo / 'emacs.d/var']:
            p.mkdir(parents=True)
        (self.home / '.zshrc').write_text('keep me')
        result = self.run_deploy('link', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('collision', result.stderr)
        self.assertEqual((self.home / '.zshrc').read_text(), 'keep me')

if __name__ == '__main__': unittest.main()
