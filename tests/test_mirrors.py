"""Mirror transforms preserve trust; failures restore the exact previous config."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
from workbench import mirrors
from workbench.registry import discover
from workbench.cli import workflow


class MirrorsTests(unittest.TestCase):
    def setUp(self):
        self.settings = mirrors.catalog(REPO)
        self.site = self.settings['sites']['tuna']

    def test_priority_skips_unsupported_flathub(self):
        self.assertEqual([name for name, _ in mirrors.candidates(self.settings, 'dnf')], ['tuna', 'ustc', 'sjtu'])
        self.assertEqual([name for name, _ in mirrors.candidates(self.settings, 'flatpak')], ['ustc', 'sjtu'])

    def test_apt_legacy_preserves_options_third_party_and_security(self):
        text = ('deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu noble main universe\n'
                'deb http://security.ubuntu.com/ubuntu noble-security main\n'
                'deb https://ppa.launchpadcontent.net/example/ubuntu noble main\n')
        result, urls = mirrors.apt_transform(text, self.site, self.settings)
        self.assertIn('signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg]', result)
        self.assertIn('https://ppa.launchpadcontent.net/example/ubuntu noble main', result)
        self.assertIn('https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ noble-security', result)
        self.assertEqual(len(urls), 2)
        self.assertEqual(mirrors.apt_transform(result, self.site, self.settings)[0], result)

    def test_apt_deb822_ports_continuations_and_disabled_suites(self):
        text = ('Types: deb deb-src\nURIs: http://ports.ubuntu.com/ubuntu-ports\n'
                'Suites: noble\n noble-updates noble-security\nComponents: main universe\n'
                'Architectures: arm64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\n'
                'Types: deb\nURIs: https://archive.ubuntu.com/ubuntu\nSuites: invalid\nEnabled: no\n')
        result, urls = mirrors.apt_transform(text, self.site, self.settings, True)
        self.assertEqual(len(urls), 3)
        self.assertTrue(all('/ubuntu-ports/dists/noble' in u for u in urls))
        self.assertIn('Architectures: arm64', result)
        self.assertIn('Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg', result)
        self.assertIn('Enabled: no', result)

    def test_dnf_keeps_gpg_keys_disabled_sections_and_other_repos(self):
        text = ('[fedora]\nname=Fedora\nmetalink=https://example/metalink\n#baseurl=http://download.example/pub/fedora/linux\n'
                'enabled=1\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/key\n\n'
                '[fedora-source]\nmetalink=https://example/source\nenabled=0\ngpgcheck=1\n\n'
                '[vendor]\nbaseurl=https://vendor.invalid/repo\nenabled=1\n')
        result, urls = mirrors.dnf_transform(text, self.site, '44', 'x86_64')
        self.assertNotIn('metalink=', result)
        self.assertIn('baseurl=https://vendor.invalid/repo', result)
        self.assertIn('gpgkey=file:///etc/pki/rpm-gpg/key', result)
        self.assertEqual(result.count('gpgcheck=1'), 2)
        self.assertEqual(len(urls), 1)
        self.assertIn('/releases/44/Everything/x86_64/os/repodata/repomd.xml', urls[0])
        self.assertIn('$releasever', result)
        self.assertEqual(mirrors.dnf_transform(result, self.site, '44', 'x86_64')[0], result)

    def test_validation_failure_rolls_back_all_files_and_retains_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); current = {'one': 'old1', 'two': 'old2'}; before = dict(current)
            def writer(key, value): current[key] = value
            def invalid(*args): raise subprocess.CalledProcessError(1, ['apt-get', 'update'])
            with self.assertRaises(subprocess.CalledProcessError):
                mirrors.transaction(root, 'apt', before, {'one': 'new1', 'two': 'new2'}, 'tuna', writer, invalid)
            self.assertEqual(current, before)
            self.assertFalse((root/'data/mirrors/apt.json').exists())
            self.assertFalse((root/'data/mirrors/apt.pending.json').exists())
            self.assertEqual(json.loads(next((root/'backups/mirrors').glob('*.json')).read_text()), before)

    def test_repeat_updates_keep_original_for_restore_and_detect_user_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); state = {'system': 'official'}
            def writer(key, value): state[key] = value
            mirrors.transaction(root, 'flatpak', dict(state), {'system': 'tuna'}, 'tuna', writer, lambda *_: None)
            mirrors.transaction(root, 'flatpak', dict(state), {'system': 'ustc'}, 'ustc', writer, lambda *_: None)
            record = json.loads((root/'data/mirrors/flatpak.json').read_text())
            self.assertEqual(record['original'], {'system': 'official'})
            with self.assertRaisesRegex(RuntimeError, 'outside Workbench'):
                mirrors.transaction(root, 'flatpak', {'system': 'user-edited'}, {'system': 'tuna'}, 'tuna', writer, lambda *_: None)
            with patch.object(mirrors, 'flatpak_remotes', return_value=dict(state)), patch.object(mirrors, 'write_flatpak', side_effect=writer):
                mirrors.restore(root, 'flatpak')
            self.assertEqual(state, {'system': 'official'})

    def test_denied_authorization_does_not_retry_unchanged_url_during_rollback(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch.object(mirrors, 'write_flatpak', side_effect=subprocess.CalledProcessError(1, ['flatpak'])) as writer:
                with self.assertRaises(subprocess.CalledProcessError):
                    mirrors.transaction(root, 'flatpak', {'system': 'official'}, {'system': 'mirror'},
                                        'ustc', writer, lambda *_: None, lambda: {'system': 'official'})
                self.assertEqual(writer.call_count, 1)
            self.assertFalse((root/'data/mirrors/flatpak.pending.json').exists())

    def test_interrupted_transaction_reports_pending_and_can_restore(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); state = {'system': 'partial'}
            mirrors.save(root/'data/mirrors/flatpak.pending.json', {'before': {'system': 'official'}})
            self.assertEqual(mirrors.mirror_action('check', ['flatpak'], REPO, root, 'steamdeck'), 2)
            with patch.object(mirrors, 'flatpak_remotes', return_value=dict(state)), \
                 patch.object(mirrors, 'write_flatpak', side_effect=lambda k, v: state.update({k: v})):
                mirrors.restore(root, 'flatpak')
            self.assertEqual(state, {'system': 'official'})

    def test_probe_rejects_captive_portal_html(self):
        class Reply:
            status = 200
            url = 'https://mirrors.example/metadata'
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, size): return b'<html>sign in</html>'
        with patch.object(mirrors.urllib.request, 'build_opener') as opener:
            opener.return_value.open.return_value = Reply()
            for kind in ('apt', 'dnf', 'flatpak', 'summary'):
                with self.assertRaises(RuntimeError): mirrors.probe('https://mirrors.example/metadata', kind)

    def test_all_candidates_offline_make_no_changes(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(mirrors, 'flatpak_remotes', return_value={'system': 'official'}), \
             patch.object(mirrors, 'probe', side_effect=OSError('offline')), patch.object(mirrors, 'write_flatpak') as writer:
            with self.assertRaisesRegex(RuntimeError, 'No usable mirror'):
                mirrors.mirror_action('apply', ['flatpak'], REPO, Path(tmp), 'steamdeck')
            writer.assert_not_called()
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_workflows_prepare_mirrors_before_native_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); components = discover(REPO, root)
            for platform, target in mirrors.DEFAULTS.items():
                plan = workflow(components, 'install', [], REPO, root, platform)
                self.assertEqual((plan[0]['component'], plan[0]['action'], plan[0]['command'][-1]), ('mirrors', 'install', target))
            self.assertNotEqual(workflow(components, 'install', [], REPO, root, 'macos')[0]['component'], 'mirrors')

    def test_command_completion_and_cross_platform_plan_are_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            for args in [('--complete', 'targets', 'mirrors', 'apply'), ('--platform', 'ubuntu', 'mirrors', 'apply', 'apt', '--plan')]:
                result = subprocess.run([sys.executable, str(REPO/'bin/workbench'), '--prefix', tmp, *args], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('apt', result.stdout)
                self.assertEqual(list(Path(tmp).iterdir()), [])
