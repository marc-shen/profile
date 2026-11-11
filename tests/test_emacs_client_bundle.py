"""Verify runtime/launcher assembly without changing installed applications."""
from pathlib import Path
import json
import plistlib
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'libexec'))
from emacs_client_bundle import (build_bundle, runtime_signature, ensure_runtime,
                                 selected_runtime, input_link, INPUT, MARKER, OVERLAY)


class BundleTests(unittest.TestCase):
    def test_runtime_metadata_and_helpers_share_one_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            runtime, overlay, target = [root / n for n in ('upstream.app', 'source.app', 'Client.app')]
            for app in (runtime, overlay):
                (app / 'Contents/MacOS').mkdir(parents=True)
                (app / 'Contents/Resources').mkdir()
            (runtime / 'Contents/_CodeSignature').mkdir()
            (runtime / 'Contents/_CodeSignature/CodeResources').write_bytes(b'signed resources')
            (runtime / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'org.gnu.Emacs', 'CFBundleExecutable': 'Emacs',
                'NSPrincipalClass': 'EmacsApp', 'NSServices': ['preserved']}))
            (overlay / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'local.marcshen.emacs-client',
                'CFBundleExecutable': 'emacs-client-launcher'}))
            (runtime / 'Contents/MacOS/Emacs').write_bytes(b'native core')
            (runtime / 'Contents/Resources/lisp').mkdir()
            (overlay / 'Contents/MacOS/emacs-client-launcher').write_bytes(b'launcher')
            (overlay / 'Contents/Resources/activate-emacs').write_bytes(b'helper')
            def run(command, **kwargs):
                if command[0] == '/usr/bin/ditto':
                    shutil.copytree(command[1], command[2])
            with patch('emacs_client_bundle.subprocess.run', side_effect=run):
                build_bundle(overlay, runtime, target, 'overlay-hash')
            info = plistlib.loads((target / 'Contents/Info.plist').read_bytes())
            self.assertEqual(info['CFBundleIdentifier'], 'local.marcshen.emacs-client')
            self.assertEqual(info['NSPrincipalClass'], 'EmacsApp')
            self.assertEqual(info['NSServices'], ['preserved'])
            self.assertEqual((target / 'Contents/MacOS/Emacs').read_bytes(), b'native core')
            self.assertTrue((target / 'Contents/MacOS/emacs-client-launcher').is_file())
            self.assertTrue((target / 'Contents/Resources/lisp').is_dir())
            marker = json.loads((target / 'Contents/Resources/profile-runtime.json').read_text())
            self.assertEqual(marker, {'format': 2, 'overlay': 'overlay-hash',
                                      'runtime': runtime_signature(runtime), 'input': str(runtime)})

            self.assertEqual((target / INPUT).resolve(), runtime.resolve())
            self.assertTrue((target / OVERLAY / 'Contents/MacOS/emacs-client-launcher').is_file())
            self.assertFalse(ensure_runtime(target, root / 'backups'))
            # A dropped app replaces the default link and remains a real copy
            # after an automatic update. The upstream input is never patched.
            (target / INPUT).unlink()
            shutil.copytree(runtime, target / INPUT)
            # Changing only the source representation must refresh the seal too.
            with patch('emacs_client_bundle.subprocess.run', side_effect=run):
                self.assertTrue(ensure_runtime(target, root / 'backups'))
            replacement = target / INPUT
            info_path = replacement / 'Contents/Info.plist'
            info = plistlib.loads(info_path.read_bytes())
            info['CFBundleShortVersionString'] = '99.1'
            info_path.write_bytes(plistlib.dumps(info))
            with patch('emacs_client_bundle.subprocess.run', side_effect=run):
                self.assertTrue(ensure_runtime(target, root / 'backups'))
            self.assertFalse((target / INPUT).is_symlink())
            self.assertEqual(plistlib.loads((target / INPUT / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'], 'org.gnu.Emacs')
            self.assertEqual(plistlib.loads((target / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'], '99.1')
            self.assertFalse(ensure_runtime(target, root / 'backups'))
            self.assertEqual(len(list((root / 'backups').iterdir())), 2)
            # An invalid replacement fails without changing the working files.
            shutil.rmtree(target / INPUT)
            (target / INPUT).symlink_to(root / 'missing.app')
            self.assertEqual(selected_runtime(target), target / INPUT)
            before = (target / 'Contents/MacOS/Emacs').read_bytes()
            with self.assertRaises(FileNotFoundError):
                ensure_runtime(target, root / 'backups')
            self.assertEqual((target / 'Contents/MacOS/Emacs').read_bytes(), before)
            # Signing failure also leaves the installed application intact.
            (target / INPUT).unlink()
            (target / INPUT).symlink_to(runtime)
            with patch('emacs_client_bundle.subprocess.run', side_effect=RuntimeError('invalid signature')):
                with self.assertRaisesRegex(RuntimeError, 'invalid signature'):
                    ensure_runtime(target, root / 'backups')
            self.assertEqual((target / 'Contents/MacOS/Emacs').read_bytes(), before)
            with self.assertRaises(FileExistsError):
                build_bundle(overlay, runtime, target, 'again')

    def test_external_link_keeps_stable_path_instead_of_pinning_brew_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            versioned = root / 'Caskroom/31.1/Emacs.app'
            versioned.mkdir(parents=True)
            stable = root / 'Applications/Emacs.app'
            stable.parent.mkdir()
            stable.symlink_to(versioned)
            self.assertEqual(input_link(stable), str(stable))
            slot = root / 'Client.app' / INPUT
            slot.parent.mkdir(parents=True)
            slot.symlink_to(stable)
            self.assertEqual(input_link(slot), str(stable))

if __name__ == '__main__': unittest.main()
