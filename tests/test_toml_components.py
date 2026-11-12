"""Verify source-of-truth manifests, filtering and minimal software dependencies."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
sys.path.insert(0, str(REPO / 'libexec'))
from workbench.data import CATEGORIES, specifications, tool_specs, language_specs
from workbench.registry import discover
from workbench.engine import plan
from python_runtime import ensure


class ComponentTests(unittest.TestCase):
    def test_each_software_has_one_toml_definition_and_use_category(self):
        specs = specifications(REPO)
        self.assertEqual(specs['node']['category'], 'development')
        self.assertEqual(specs['node']['install']['provider'], 'nvm')
        self.assertEqual(specs['fzf-tab']['category'], 'terminal')
        self.assertEqual(specs['wezterm']['category'], 'terminal')
        self.assertTrue(all(spec['category'] in CATEGORIES for spec in specs.values()))
        self.assertFalse(list((REPO / 'components').glob('*/component.json')))
        self.assertFalse((REPO / 'catalog/tools.json').exists())
        self.assertEqual(tool_specs(REPO)['node']['version'], specs['node']['install']['version'])
        self.assertEqual(language_specs(REPO)['python']['package'], specs['basedpyright']['install']['package'])

    def test_individual_install_only_plans_its_needed_provider(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve() / 'Software'
            specs = discover(REPO, root)
            steps = plan(specs, 'fd', 'install', [], REPO, root, 'macos')
            self.assertEqual([(s['component'], s['action']) for s in steps], [('providers', 'install'), ('fd', 'install')])
            self.assertEqual(steps[0]['command'][-1], 'pixi')
            self.assertEqual([s['component'] for s in plan(specs, 'node', 'update', [], REPO, root, 'macos')], ['node'])
            self.assertFalse(root.exists())

    def test_filters_and_filter_completion_remain_machine_readable(self):
        for flags in [('--category', 'development'), ('--tag', 'runtime')]:
            result = subprocess.run([sys.executable, str(REPO / 'bin/workbench'), 'list', *flags, '--json'],
                                    capture_output=True, text=True, check=True)
            data = json.loads(result.stdout)
            self.assertIn('node', [s['name'] for s in data])
            self.assertNotIn('fzf-tab', [s['name'] for s in data])
        result = subprocess.run([sys.executable, str(REPO / 'bin/workbench'), '--complete', 'categories'],
                                capture_output=True, text=True, check=True)
        self.assertEqual(set(result.stdout.splitlines()), set(CATEGORIES))

    def test_bootstrap_managed_python_is_repeatable_without_system_modification(self):
        if sys.version_info[:2] != (3, 12): self.skipTest('Run Python provisioning test under Python 3.12')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve() / 'Software'
            (root / 'bin').mkdir(parents=True)
            uv = root / 'bin/uv'
            # Fake only the downloader; use a real interpreter for version verification.
            uv.write_text('#!' + sys.executable + '\nimport sys,json,pathlib\n'
                          'root=pathlib.Path(__file__).resolve().parents[1]\n'
                          'with (root/"calls").open("a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\n'
                          'if sys.argv[1:3]==["python","find"]:print(' + repr(sys.executable) + ')\n')
            uv.chmod(0o755)
            binary = ensure(root)
            before = (root / 'calls').read_text()
            self.assertEqual(ensure(root), binary)
            self.assertEqual((root / 'calls').read_text(), before)
            self.assertTrue((root / 'bin/python3').is_symlink())
            self.assertEqual((root / 'bin/python3').resolve(), Path(sys.executable).resolve())
            self.assertFalse((root / 'apps/python/current/bin').is_symlink())
            probe = subprocess.run([root / 'bin/python3', '-I', '-c',
                                    'import sys; assert sys.exec_prefix == sys.prefix'],
                                   capture_output=True, text=True, check=True)
            self.assertEqual(probe.stderr, '')
            record = json.loads((root / 'apps/python/current/receipt.json').read_text())
            self.assertTrue(record['version'].startswith('3.12.'))
            self.assertEqual(record['backend'], 'uv')
