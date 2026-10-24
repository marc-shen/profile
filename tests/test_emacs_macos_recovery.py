"""Exercise recovery using a disposable process and fake launchctl, never Emacs."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'emacs.d/Emacs Client.app/Contents/Resources/restart-emacs'

class RecoveryTests(unittest.TestCase):
    def exercise(self, state):
        with tempfile.TemporaryDirectory(prefix='emacs recovery ') as tmp:
            root = Path(tmp)
            log = root / 'calls'
            child = subprocess.Popen(['/bin/sleep', '30']) if state in ('running', 'kill-fails') else None
            if child:
                waiter = threading.Thread(target=child.wait)
                waiter.start()
            try:
                shutil.copy2(SOURCE, root / 'restart-emacs')
                (root / 'activate-emacs').write_text('printf "activate %s\\n" "$*" >> "$TEST_LOG"\n')
                control = root / 'launchctl'
                control.write_text('#!' + sys.executable + '\n' + '''import os, sys, signal
from pathlib import Path
args = sys.argv[1:]
assert args[-1] == 'gui/' + str(os.getuid()) + '/org.gnu.emacs.daemon'
with Path(os.environ['TEST_LOG']).open('a') as f: f.write(' '.join(args) + '\\n')
state = os.environ['TEST_STATE']
if args[0] == 'print':
    if state == 'unloaded': sys.exit(1)
    if state in ('running', 'kill-fails'): print('    pid = ' + os.environ['TEST_PID'])
elif args[:2] == ['kill', 'SIGKILL']:
    if state == 'kill-fails': sys.exit(1)
    os.kill(int(os.environ['TEST_PID']), signal.SIGKILL)
else: sys.exit(2)
''')
                control.chmod(0o755)
                env = dict(os.environ, PATH=str(root)+os.pathsep+os.defpath,
                           TEST_LOG=str(log), TEST_STATE=state,
                           TEST_PID=str(child.pid if child else 0))
                result = subprocess.run(['/bin/bash', str(root / 'restart-emacs')],
                                        env=env, capture_output=True, text=True, timeout=10)
                calls = log.read_text()
                if state == 'kill-fails':
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn('activate', calls)
                    self.assertIsNone(child.poll())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn('activate --new-window', calls)
                    self.assertEqual('kill SIGKILL' in calls, state == 'running')
                    if child:
                        waiter.join(timeout=2)
                        self.assertEqual(child.returncode, -9)
            finally:
                if child:
                    if child.poll() is None: child.kill()
                    waiter.join(timeout=3)

    def test_running_daemon_is_killed_before_reopen(self): self.exercise('running')
    def test_unloaded_service_is_reopened_without_killing(self): self.exercise('unloaded')
    def test_loaded_service_without_pid_is_reopened(self): self.exercise('stopped')
    def test_failed_kill_does_not_open_another_instance(self): self.exercise('kill-fails')

if __name__ == '__main__': unittest.main()
