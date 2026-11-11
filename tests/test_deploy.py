"""Exercise data preservation and idempotency in an isolated HOME and checkout."""
import os
from pathlib import Path
import shutil
import subprocess as sp
import tempfile
import sys
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
        for name in ['libexec', 'docs', 'config/helix', 'config/shell', 'platforms']:
            shutil.copytree(SOURCE / name, self.repo / name)
        for name in ['config/starship', 'config/wezterm']:
            shutil.copytree(SOURCE / name, self.repo / name)
        (self.repo / 'config/emacs').mkdir(parents=True)
        for name in ['em', 'ec', 'ediff', 'init.el']:
            shutil.copy2(SOURCE / 'config/emacs' / name, self.repo / 'config/emacs' / name)
        self.env = dict(os.environ, HOME=str(self.home), SOFTWARE_HOME=str(self.home / 'Software'),
                        SOFTWARE_USER_HOME=str(self.home / 'Software'), WORKBENCH_HOME=str(self.repo),
                        PYTHONDONTWRITEBYTECODE='1')
    def tearDown(self): self.tmp.cleanup()
    def run_deploy(self, *args, check=True):
        return sp.run([sys.executable, '-B', str(self.repo / 'libexec/deploy.py'), *args], env=self.env,
                      capture_output=True, text=True, check=check)
    def test_shared_checkout_runtime_is_never_moved_to_another_home(self):
        runtime = self.repo / 'config/emacs/var'
        runtime.mkdir()
        (runtime / 'history').write_text('other home state')
        result = self.run_deploy('link', '--only', 'emacs', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((runtime / 'history').read_text(), 'other home state')
        self.assertFalse((self.home / 'Software/data/emacs').exists())

    def test_old_compatibility_link_is_repointed_to_canonical_configuration(self):
        alias = self.repo / 'zshrc'
        alias.symlink_to('config/shell/zshrc')
        (self.home / '.zshrc').symlink_to(alias)
        self.run_deploy('link', '--only', 'shell')
        self.assertEqual((self.home / '.zshrc').readlink(), self.repo / 'config/shell/zshrc')

    def test_fresh_emacs_runtime_targets_allow_first_package_and_history_writes(self):
        self.run_deploy('link', '--only', 'emacs')
        for name in ['elpa', 'var', 'eln-cache', 'tree-sitter', 'transient', 'log']:
            directory=self.home/'.emacs.d'/name
            self.assertTrue(directory.is_dir(),name)
            (directory/'first-write').write_text('new installation')
            self.assertEqual((self.home/'Software/data/emacs'/name/'first-write').read_text(),'new installation')
        (self.home/'.emacs.d/custom.el').write_text('; local setting\n')
        self.assertEqual((self.home/'Software/data/emacs/custom.el').read_text(),'; local setting\n')
        self.run_deploy('link', '--only', 'emacs')
        self.assertEqual((self.home/'.emacs.d/elpa/first-write').read_text(),'new installation')

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
        self.assertEqual((self.home / '.emacs.d').resolve(), self.repo / 'config/emacs')
        self.assertEqual((self.home / 'Software/bin/ediff').resolve(), self.repo / 'config/emacs/ediff')
        self.assertEqual((self.home / '.emacs.d/var/history').read_text(), 'keep session data')
        self.assertTrue((self.repo / 'config/emacs/var').is_symlink())
        self.assertEqual((self.home / 'Software/data/emacs/var/history').read_text(), 'keep session data')
        backup = list((self.home / 'Software/backups').glob('profile-*'))
        self.assertEqual(len(backup), 1)
        self.assertEqual((backup[0] / '.zshrc').read_text(), 'private local preference\n')
        self.assertIn('export KEEP_ME=yes', (self.home / '.zshenv').read_text())
        self.run_deploy('link')
        self.assertEqual(backup, list((self.home / 'Software/backups').glob('profile-*')))
    def test_helix_only_backs_up_config_without_replacing_shell(self):
        dest = self.home / '.config/helix'
        dest.mkdir(parents=True)
        (dest / 'config.toml').write_text('theme = "old"')
        (self.home / '.zshrc').write_text('# personal shell')
        self.run_deploy('link', '--only', 'helix')
        self.assertEqual(dest.resolve(), self.repo / 'config/helix')
        backups = list((self.home / 'Software/backups').glob('profile-*/.config/helix/config.toml'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'theme = "old"')
        self.assertEqual((self.home / '.zshrc').read_text(), '# personal shell')
        self.assertFalse((self.home / '.emacs.d').exists())
        self.run_deploy('link', '--only', 'helix')
        self.assertEqual(backups, list((self.home / 'Software/backups').glob('profile-*/.config/helix/config.toml')))

    def test_retired_nvim_link_is_backed_up_even_when_dangling(self):
        dest = self.home / '.config/nvim'
        dest.parent.mkdir()
        dest.symlink_to(self.repo / 'nvim')
        self.run_deploy('link', '--only', 'shell')
        self.assertFalse(dest.is_symlink())
        # Python 3.9 glob can omit dangling symlinks at its final path segment.
        backups = [p / 'nvim' for p in (self.home / 'Software/backups').glob('profile-*/.config')
                   if (p / 'nvim').is_symlink()]
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].readlink(), self.repo / 'nvim')
        self.run_deploy('link', '--only', 'shell')
        self.assertFalse(dest.exists())

    def test_unmanaged_nvim_config_is_preserved(self):
        dest = self.home / '.config/nvim'
        dest.mkdir(parents=True)
        (dest / 'init.lua').write_text('-- personal config')
        self.run_deploy('link', '--only', 'shell')
        self.assertEqual((dest / 'init.lua').read_text(), '-- personal config')
        shutil.rmtree(dest)
        other = self.home / 'independent-nvim'
        other.mkdir()
        dest.symlink_to(other)
        self.run_deploy('link', '--only', 'shell')
        self.assertEqual(dest.resolve(), other)

    def test_conflicting_runtime_refuses_without_replacing_shell(self):
        for p in [self.home / '.emacs.d/var', self.repo / 'config/emacs/var']:
            p.mkdir(parents=True)
        (self.home / '.zshrc').write_text('keep me')
        result = self.run_deploy('link', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('collision', result.stderr)
        self.assertEqual((self.home / '.zshrc').read_text(), 'keep me')

    def test_emacs_only_creates_shared_environment_without_replacing_shell(self):
        (self.home / '.zshrc').write_text('# personal shell\n')
        self.run_deploy('link', '--only', 'emacs')
        environment = self.home / 'Software/env.sh'
        self.assertTrue(environment.is_file())
        self.assertIn(str(self.repo / 'config/shell/env.sh'), environment.read_text())
        self.assertIn(str(self.repo / 'config/shell/modules.sh'), environment.read_text())
        self.assertEqual((self.home / '.zshrc').read_text(), '# personal shell\n')
        self.assertFalse((self.home / '.zprofile').exists())
        before = environment.stat().st_mtime_ns
        self.run_deploy('link', '--only', 'emacs')
        self.assertEqual(environment.stat().st_mtime_ns, before)

if __name__ == '__main__': unittest.main()
