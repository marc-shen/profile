"""Check Dock request ordering and evaluate frame selection without a GUI."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'emacs.d/Emacs Client.app/Contents/Resources/activate-emacs'
EMACS = shutil.which('emacs') or '/Applications/Emacs.app/Contents/MacOS/Emacs'


class ActivationTests(unittest.TestCase):
    def request(self, arguments=(), existing=True):
        with tempfile.TemporaryDirectory(prefix='emacs activation ') as tmp:
            root = Path(tmp)
            client = root / 'client'
            client.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
with open(os.environ['TEST_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
print('nil' if '(let* ((frames' in sys.argv[-1] and os.environ['TEST_EXISTING'] == '0' else 't')
''')
            client.chmod(0o755)
            script = root / 'activate'
            script.write_text(SOURCE.read_text().replace(
                'if [[ ! -x $client ]]; then client=/Applications/Emacs.app/Contents/MacOS/bin/emacsclient; fi',
                'client="' + str(client) + '"'))
            log = root / 'calls'
            subprocess.run(['/bin/bash', str(script), *arguments], check=True,
                           capture_output=True, timeout=10,
                           env=dict(os.environ, TEST_LOG=str(log),
                                    TEST_EXISTING='1' if existing else '0'))
            return [json.loads(line) for line in log.read_text().splitlines()]

    def test_existing_and_new_frames_activate_after_final_policy_change(self):
        for arguments, existing in [((), True), ((), False), (('--new-window',), True),
                                    (('a file.txt',), True)]:
            with self.subTest(arguments=arguments, existing=existing):
                calls = self.request(arguments, existing)
                evaluations = [c[-1] for c in calls if '--eval' in c]
                self.assertIn('setActivationPolicy:0', evaluations[-1])
                self.assertFalse(any('setActivationPolicy:1' in e for e in evaluations))
                self.assertTrue(any('(menu-bar-mode 1)' in e for e in evaluations))
                self.assertLess(evaluations[-1].index('setActivationPolicy:0'),
                                evaluations[-1].index('activateIgnoringOtherApps:true'))
                self.assertIn('activateIgnoringOtherApps:true', evaluations[-1])
                self.assertIn('select-frame-set-input-focus', evaluations[-1])
                self.assertFalse(any('select-frame-set-input-focus' in e for e in evaluations[:-1]))
                self.assertEqual(any('--create-frame' in c for c in calls),
                                 bool(arguments) or not existing)

    @unittest.skipUnless(Path(EMACS).is_file(), 'Requires Emacs')
    def test_selection_keeps_current_frame_and_excludes_child_and_terminal(self):
        expression = next(c[-1] for c in self.request() if '(let* ((frames' in c[-1])
        # Run the actual emitted Lisp with fake frames, never touching GUI focus.
        program = '''(progn (require 'cl-lib) (require 'seq)
          (dolist (selected '(second child terminal))
            (let (target)
              (cl-letf (((symbol-function 'frame-list)
                         (lambda () '(terminal child first second)))
                        ((symbol-function 'display-graphic-p)
                         (lambda (f) (not (eq f 'terminal))))
                        ((symbol-function 'frame-parent)
                         (lambda (f) (and (eq f 'child) 'second)))
                        ((symbol-function 'selected-frame) (lambda () selected))
                        ((symbol-function 'set-frame-parameter)
                         (lambda (f _p _v) (setq target f))))
                EXPRESSION
                (unless (eq target (if (memq selected '(second child)) 'second 'first))
                  (error "Wrong activation target: %S" target))))))'''.replace('EXPRESSION', expression)
        subprocess.run([EMACS, '--batch', '-Q', '--eval', program], check=True,
                       capture_output=True, timeout=15)


if __name__ == '__main__':
    unittest.main()
