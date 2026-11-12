"""Presentation must not corrupt completion, JSON, exit codes or saved logs."""
import io
import json
import os
from pathlib import Path
import pty
import select
import time
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
from workbench.ui import Console, width
from workbench.engine import execute, lock


class TTY(io.StringIO):
    def isatty(self): return True


class OutputTests(unittest.TestCase):
    def test_open_does_not_hold_or_require_installation_lock(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # The launched process must be able to acquire the installation lock.
            script = ('import os,fcntl,pathlib; '
                      'p=pathlib.Path(os.environ["SOFTWARE_HOME"])/"data/workbench/operation.lock"; '
                      'p.parent.mkdir(parents=True,exist_ok=True); '
                      'f=p.open("a"); fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)')
            step = dict(component='example', action='open', command=[sys.executable, '-c', script])
            self.assertEqual(execute([step], REPO, root, 'steamdeck'), 0)
            # An existing GUI or installer holding the lock must not prevent launch.
            with lock(root):
                step['command'] = [sys.executable, '-c', 'import sys; sys.exit(7)']
                self.assertEqual(execute([step], REPO, root, 'steamdeck'), 7)
                step['action'] = 'install'
                with patch('os.geteuid', return_value=1000), self.assertRaisesRegex(RuntimeError, 'Another workbench'):
                    execute([step], REPO, root, 'steamdeck')

    def test_color_policy_and_unicode_alignment(self):
        with patch.dict(os.environ, {'TERM': 'xterm-256color', 'COLUMNS': '48'}, clear=True):
            stream = TTY(); console = Console(stream)
            console.table([('中文', '[OK] 可用'), ('tools', 'long ' * 20)])
            self.assertIn('\033[', stream.getvalue())
            lines = stream.getvalue().splitlines()
            self.assertTrue(all(width(line) <= 48 for line in lines))
            self.assertEqual(width(lines[0].split('[OK]')[0].replace('\033[32m', '')), 9)
            self.assertFalse(Console(io.StringIO()).color)
            with patch.dict(os.environ, {'NO_COLOR': ''}): self.assertFalse(Console(TTY()).color)
            with patch.dict(os.environ, {'TERM': 'dumb'}): self.assertFalse(Console(TTY()).color)

    def test_real_tty_colors_human_output_but_not_json_or_completion(self):
        with tempfile.TemporaryDirectory() as root:
            env = dict(os.environ, SOFTWARE_HOME=root, TERM='xterm-256color')
            env.pop('NO_COLOR', None)
            for args, colored in [(('list',), True), (('--help',), True),
                                  (('list', '--json'), False), (('--complete', 'components'), False)]:
                master, slave = pty.openpty()
                try:
                    proc = subprocess.Popen([sys.executable, '-B', str(REPO / 'bin/workbench'), *args],
                                            stdout=slave, stderr=subprocess.PIPE, env=env)
                    os.close(slave); slave = None
                    chunks = []
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        if not select.select([master], [], [], .1)[0]: continue
                        try: chunk = os.read(master, 65536)
                        except OSError: break
                        if not chunk: break
                        chunks.append(chunk)
                    _, errors = proc.communicate(timeout=2)
                    self.assertEqual(proc.returncode, 0, errors)
                    output = b''.join(chunks).decode()
                    self.assertEqual('\033[' in output, colored)
                    if '--json' in args: self.assertIsInstance(json.loads(output), list)
                    if '--complete' in args: self.assertIn('components:', output)
                finally:
                    if proc.poll() is None: proc.kill()
                    proc.communicate()
                    os.close(master)
                    if slave is not None: os.close(slave)

    def test_help_shows_actual_required_optional_and_single_target_arguments(self):
        for args, expected in [(('components', 'create'), '<name> [--shared]'),
                               (('profile', 'apply'), '[--only <scope>] [--config-only]'),
                               (('system', 'install'), '[<profile>]'),
                               (('emacs', 'restart'), '[service]')]:
            result = subprocess.run([sys.executable, '-B', str(REPO / 'bin/workbench'), *args, '--help'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(expected, result.stdout)
            self.assertNotIn('\033[', result.stdout)

    def test_failure_status_exit_code_and_plain_log(self):
        with tempfile.TemporaryDirectory() as tmp, patch('os.geteuid', return_value=1000):
            root = Path(tmp)
            script = 'import sys; print("\\033[31mbackend error\\033[0m"); sys.exit(7)'
            step = dict(component='example', action='install', command=[sys.executable, '-c', script])
            output = io.StringIO()
            with patch('sys.stdout', output):
                self.assertEqual(execute([step], REPO, root, 'macos'), 7)
            self.assertIn('[1/1]', output.getvalue())
            self.assertIn('[FAIL]', output.getvalue())
            self.assertNotIn('[DONE]', output.getvalue())
            log = next((root / 'logs').glob('*.log')).read_text()
            self.assertEqual(log, 'backend error\n')
            receipt = json.loads(next((root / 'data/workbench/runs').glob('*.json')).read_text())
            self.assertEqual(receipt['status'], 'failed')
