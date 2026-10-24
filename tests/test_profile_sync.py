"""Exercise deployment snapshots and failure recovery in an isolated checkout."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess as sp
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]

class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name).resolve()
        self.home = base / 'home'; self.home.mkdir()
        self.repo = base / 'repo'; self.repo.mkdir()
        self.root = self.home / 'Software'
        for name in ['scripts', 'shell', 'docs', 'helix']:
            shutil.copytree(SOURCE / name, self.repo / name)
        shutil.copy2(SOURCE / 'bootstrap.sh', self.repo / 'bootstrap.sh')
        self.env = dict(os.environ, HOME=str(self.home), SOFTWARE_HOME=str(self.root),
                        SOFTWARE_USER_HOME=str(self.root), PROFILE_HOME=str(self.repo),
                        PYTHONDONTWRITEBYTECODE='1')
        self.git('init', '-b', 'main')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Profile Test')
        self.git('add', '.')
        self.git('commit', '-m', 'initial')

    def tearDown(self): self.tmp.cleanup()
    def git(self, *args):
        return sp.check_output(['git', '-C', str(self.repo), *args], env=self.env, stderr=sp.DEVNULL, text=True).strip()
    def run_sync(self, action='apply', *args):
        return sp.run([sys.executable, '-B', str(self.repo / 'scripts/profile-sync.py'), action,
                       '--prefix', str(self.root), '--only', 'helix', *args], env=self.env,
                      capture_output=True, text=True)
    def state(self): return json.loads((self.root / 'data/profile/deployment.json').read_text())
    def install_stubs(self):
        (self.root / 'bin').mkdir(parents=True)
        for command in ['uv', 'pixi', 'hx']:
            path = self.root / 'bin' / command
            path.write_text('#!/bin/sh\nexit 0\n'); path.chmod(0o755)

    def test_plan_does_not_write_or_install(self):
        result = self.run_sync('apply', '--plan')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('will be installed', result.stdout)
        self.assertFalse(self.root.exists())
        self.assertEqual(list(self.home.iterdir()), [])

    def test_default_apply_installs_missing_managers(self):
        (self.repo / 'scripts/software.py').write_text('''import os,sys
from pathlib import Path
assert sys.argv[1] == 'managers'
target = Path(os.environ['SOFTWARE_HOME']) / 'bin' / sys.argv[2]
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text('#!/bin/sh\\nexit 0\\n')
target.chmod(0o755)
''')
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'bin/uv').is_file())
        self.assertTrue((self.root / 'bin/pixi').is_file())
        self.assertEqual(self.state()['last_attempt']['status'], 'ok')

    def test_config_only_reports_missing_without_installing(self):
        (self.repo / 'scripts/software.py').write_text('raise AssertionError("must not install")\n')
        result = self.run_sync('apply', '--config-only')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.root / 'bin/uv').exists())
        self.assertEqual(self.state()['last_attempt']['status'], 'pending')

    def test_public_sync_help_exposes_only_daily_options(self):
        result = sp.run([sys.executable, '-B', str(self.repo / 'scripts/bootstrap.py'), 'sync', '--help'],
                        env=self.env, capture_output=True, text=True, check=True)
        for option in ['--plan', '--config-only', '--only']:
            self.assertIn(option, result.stdout)
        for option in ['--component', '--tool', '--reinstall', '--install-missing', '--scope', '--prefix']:
            self.assertNotIn(option, result.stdout)

    def test_removed_install_missing_option_is_rejected(self):
        for action in ['apply', 'sync']:
            result = sp.run([sys.executable, '-B', str(self.repo / 'scripts/bootstrap.py'),
                             action, '--install-missing'], env=self.env,
                            capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('unrecognized arguments: --install-missing', result.stderr)
            direct = self.run_sync(action, '--install-missing')
            self.assertEqual(direct.returncode, 2)
            self.assertIn('unrecognized arguments: --install-missing', direct.stderr)
        self.assertFalse(self.root.exists())

    def test_manual_git_update_is_compared_with_last_applied_snapshot(self):
        self.install_stubs()
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        previous = self.state()['scopes']['helix']
        config = self.repo / 'helix/config.toml'
        config.write_text(config.read_text() + '\n# changed on another device\n')
        self.git('add', '.'); self.git('commit', '-m', 'updated configuration')
        preview = self.run_sync('apply', '--plan')
        self.assertIn('helix/config.toml', preview.stdout)
        self.assertEqual(self.state()['scopes']['helix'], previous)
        self.assertEqual(self.run_sync().returncode, 0)
        self.assertEqual(self.state()['scopes']['helix']['commit'], self.git('rev-parse', 'HEAD'))
        self.assertIn('0 changed/new/removed', self.run_sync('apply', '--plan').stdout)

    def test_failed_apply_retains_successful_scope_and_records_failure(self):
        self.install_stubs(); self.assertEqual(self.run_sync().returncode, 0)
        previous = self.state()['scopes']['helix']
        (self.repo / 'scripts/deploy.py').write_text('raise SystemExit(3)\n')
        self.assertNotEqual(self.run_sync().returncode, 0)
        self.assertEqual(self.state()['scopes']['helix'], previous)
        self.assertEqual(self.state()['last_attempt']['status'], 'failed')

    def test_sync_refuses_dirty_worktree_without_stashing(self):
        path = self.repo / 'private note.txt'; path.write_text('keep me')
        result = self.run_sync('sync')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('local changes', result.stderr)
        self.assertEqual(path.read_text(), 'keep me')
        self.assertEqual(self.git('stash', 'list'), '')

    def test_sync_executes_newly_pulled_bootstrap(self):
        upstream = self.repo.parent / 'upstream'
        sp.run(['git', 'clone', '--bare', str(self.repo), str(upstream)], check=True, capture_output=True)
        self.git('remote', 'add', 'origin', str(upstream))
        self.git('fetch', 'origin')
        self.git('branch', '--set-upstream-to=origin/main')
        writer = self.repo.parent / 'writer'
        sp.run(['git', 'clone', str(upstream), str(writer)], check=True, capture_output=True)
        (writer / 'bootstrap.sh').write_text('#!/bin/sh\nprintf "UPDATED_ENTRY:%s\\n" "$*"\n')
        for args in [('config', 'user.email', 'test@example.invalid'), ('config', 'user.name', 'Test'),
                     ('add', '.'), ('commit', '-m', 'new entry'), ('push', 'origin', 'main')]:
            sp.run(['git', '-C', str(writer), *args], check=True, capture_output=True)
        result = self.run_sync('sync', '--config-only')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('UPDATED_ENTRY:apply', result.stdout)
        self.assertIn('--config-only', result.stdout)

if __name__ == '__main__': unittest.main()
