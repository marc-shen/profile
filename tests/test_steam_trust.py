import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'libexec'))
import steam_trust


class BubblewrapHookTests(unittest.TestCase):
    def invoke(self, args, pass_fds=()):
        with tempfile.TemporaryDirectory() as tmp:
            steam = Path(tmp) / 'Steam with spaces'
            real = steam / 'steamrt64/pv-runtime/steam-runtime-steamrt/pressure-vessel/libexec/steam-runtime-tools-0/srt-bwrap'
            real.parent.mkdir(parents=True)
            real.write_text('''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
data = os.read(int(args[1]), 4096).decode() if args[:1] == ['--args'] else None
print(json.dumps({'args': args, 'data': data}))
''')
            real.chmod(0o755)
            env = dict(os.environ, STEAMROOT=str(steam))
            env.pop('STEAM_RUNTIME_STEAMRT', None)
            result = subprocess.run(['/bin/sh', steam_trust.SOURCE, *args], env=env,
                                    pass_fds=pass_fds, capture_output=True, text=True, check=True)
            self.assertEqual(result.stderr, '')
            return json.loads(result.stdout)

    def test_mount_follows_runtime_options_and_preserves_fd_and_command(self):
        reader, writer = os.pipe()
        try:
            os.write(writer, b'--ro-bind\0runtime\0/usr\0')
            command = ['/usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0/pv-adverb',
                       '--', '/bin/true', 'argument with spaces']
            result = self.invoke(['--args', str(reader), *command], (reader,))
        finally:
            os.close(reader)
            os.close(writer)
        self.assertEqual(result['data'], '--ro-bind\0runtime\0/usr\0')
        self.assertEqual(result['args'][:2], ['--args', str(reader)])
        self.assertEqual(result['args'][2:-len(command)], [
            '--ro-bind', str(steam_trust.CA_BUNDLE), str(steam_trust.CA_BUNDLE),
            '--setenv', 'SSL_CERT_FILE', str(steam_trust.CA_BUNDLE),
            '--unsetenv', 'PRESSURE_VESSEL_BWRAP',
        ])
        self.assertEqual(result['args'][-len(command):], command)

    def test_feature_probes_are_forwarded_unchanged(self):
        args = ['--ro-bind', '/', '/', '--', '/bin/true']
        self.assertEqual(self.invoke(args)['args'], args)


class SteamTrustDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.root = self.home / 'Software'
        self.proc = self.home / 'proc'
        self.proc.mkdir()
        self.ca = self.home / 'host-ca.pem'
        self.ca.write_bytes(b'current host trust bundle')
        patcher = mock.patch.object(Path, 'home', return_value=self.home)
        patcher.start()
        self.addCleanup(patcher.stop)

    def install(self):
        with mock.patch.object(steam_trust.subprocess, 'run') as run:
            steam_trust.install(self.root)
        run.assert_called_once_with(['systemctl', '--user', 'daemon-reload'], check=True)

    def check(self):
        return steam_trust.check(self.root, proc=self.proc, ca=self.ca)

    def test_install_is_persistent_but_does_not_restart_steam(self):
        self.assertIn('install', self.check()[0])
        self.install()
        hook, unit = steam_trust.bridge_paths(self.root)
        self.assertTrue(os.access(hook, os.X_OK))
        self.assertIn('PRESSURE_VESSEL_BWRAP=', unit.read_text())
        self.assertNotIn('ExecStart=', unit.read_text())
        self.assertEqual(self.check(), [])

    def test_check_requires_running_container_to_use_current_host_trust(self):
        self.install()
        pid = self.proc / '123'
        (pid / 'root/run/pressure-vessel').mkdir(parents=True)
        (pid / 'comm').write_text('steam\n')
        self.assertIn('no CA bundle', self.check()[0])
        bundle = pid / 'root/etc/ssl/certs/ca-certificates.crt'
        bundle.parent.mkdir(parents=True)
        bundle.write_bytes(b'old runtime trust bundle')
        self.assertIn('restart Steam', self.check()[0])
        bundle.write_bytes(self.ca.read_bytes())
        self.assertEqual(self.check(), [])
        self.ca.write_bytes(b'new host trust after certificate rotation')
        self.assertIn('restart Steam', self.check()[0])

    def test_changed_hook_is_not_reported_as_healthy(self):
        self.install()
        hook, _ = steam_trust.bridge_paths(self.root)
        hook.write_text('# incomplete wrapper\n')
        self.assertIn('install', self.check()[0])


if __name__ == '__main__':
    unittest.main()
