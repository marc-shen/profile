"""The daemon prepares a replacement before exec, and stops if it is invalid."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class RuntimeStartupTests(unittest.TestCase):
    def test_prepare_precedes_exec_and_failure_never_starts_old_runtime(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                contents = home / 'Applications/Emacs Client.app/Contents'
                (contents / 'MacOS').mkdir(parents=True)
                (contents / 'Resources').mkdir()
                native = contents / 'MacOS/Emacs'
                native.write_text('#!/bin/bash\nprintf "exec %s\\n" "$*" >> "$TEST_LOG"\n')
                native.chmod(0o755)
                helper = contents / 'Resources/prepare-runtime.py'
                helper.write_text('import os, sys\nfrom pathlib import Path\n'
                                  'with Path(os.environ["TEST_LOG"]).open("a") as f: f.write("prepare\\n")\n'
                                  'sys.exit(' + str(int(fail)) + ')\n')
                fake_bin = home / 'bin'
                fake_bin.mkdir()
                uname = fake_bin / 'uname'
                uname.write_text('#!/bin/sh\necho Darwin\n')
                uname.chmod(0o755)
                log = home / 'calls'
                env = dict(os.environ, HOME=str(home), SOFTWARE_HOME=str(home / 'Software'),
                           WORKBENCH_HOME=str(REPO), TEST_LOG=str(log),
                           PATH=str(fake_bin) + os.pathsep + os.defpath)
                env.pop('EMACS_BINARY', None)
                result = subprocess.run(['/bin/bash', str(REPO / 'libexec/emacs-daemon')],
                                        env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, int(fail), result.stderr)
                self.assertEqual(log.read_text(), 'prepare\n' + ('' if fail else 'exec --fg-daemon\n'))


if __name__ == '__main__':
    unittest.main()
