"""Exercise real Git updates and failures against local repositories, offline."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess as sp
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('plugins', Path(__file__).resolve().parents[1] / 'libexec/plugins.py')
plugins = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plugins)


class PluginTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.upstream = self.root / 'upstream'
        sp.run(['git', 'init', '-q', str(self.upstream)], check=True)
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        (self.upstream / 'plugin.zsh').write_text('original\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'initial')
        self.target = self.root / 'plugins/demo'

    def git(self, *args):
        return sp.check_output(['git', '-C', str(self.upstream), *args], text=True).strip()

    def test_install_update_and_dirty_protection(self):
        first = plugins.update(self.target, str(self.upstream))
        self.assertEqual(plugins.inspect(self.target), ('installed', first))
        (self.upstream / 'plugin.zsh').write_text('updated\n')
        self.git('commit', '-qam', 'update')
        self.assertEqual(plugins.update(self.target, str(self.upstream), True), first)
        second = plugins.update(self.target, str(self.upstream))
        self.assertNotEqual(first, second)
        (self.target / 'plugin.zsh').write_text('personal edit\n')
        with self.assertRaisesRegex(RuntimeError, 'local changes'):
            plugins.update(self.target, str(self.upstream))
        self.assertEqual((self.target / 'plugin.zsh').read_text(), 'personal edit\n')

    def test_failed_clone_can_be_retried(self):
        with self.assertRaisesRegex(RuntimeError, 'clone failed'):
            plugins.update(self.target, str(self.root / 'not-a-repository'))
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.target.parent.iterdir()), [])
        plugins.update(self.target, str(self.upstream))
        self.assertEqual(plugins.inspect(self.target)[0], 'installed')

    def test_partial_failures_keep_successful_receipts_and_old_completions(self):
        software = self.root / 'Software'
        records = software / 'share/zsh/plugins-installed.json'
        records.parent.mkdir(parents=True)
        records.write_text(json.dumps({'unselected': {'commit': 'keep'}}))
        completions = software / 'share/zsh/completions'
        completions.mkdir()
        (completions / '_pixi').write_text('old completion')
        binary = software / 'bin/pixi'
        binary.parent.mkdir()
        binary.write_text('#!/bin/sh\necho completion-broken >&2\nexit 9\n')
        binary.chmod(0o755)
        with patch.object(plugins.shutil, 'which', return_value=None), patch.object(plugins, 'sources', return_value={'good': str(self.upstream), 'bad': str(self.root / 'missing')}):
            result = plugins.main(['update', '--prefix', str(software)])
        self.assertEqual(result, 1)
        data = json.loads(records.read_text())
        self.assertIn('good', data)
        self.assertEqual(data['unselected']['commit'], 'keep')
        self.assertNotIn('bad', data)
        self.assertEqual((completions / '_pixi').read_text(), 'old completion')


if __name__ == '__main__':
    unittest.main()
