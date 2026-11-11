"""Verify distro capability checks without invoking a package manager."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
from workbench import provision


class PlatformProvisionTests(unittest.TestCase):
    def test_fedora_accepts_a_compatibility_package_provider(self):
        with patch.object(provision.sp, 'run', return_value=subprocess.CompletedProcess([], 0, 'zlib-ng-compat-devel\n', '')) as run:
            self.assertEqual(provision.missing_packages(['zlib-devel'], 'fedora'), [])
        self.assertEqual(run.call_args.args[0], ['rpm', '-q', '--whatprovides', 'zlib-devel'])

    def test_ubuntu_check_includes_the_installed_compilers_jit_headers(self):
        with patch.object(provision, 'missing_packages', side_effect=[[], ['libgccjit-14-dev']]) as missing, \
             patch.object(provision.sp, 'check_output', return_value='14.2.0\n'), \
             patch.object(Path, 'is_file', return_value=True), \
             contextlib.redirect_stdout(io.StringIO()):
            result = provision.platform_action('check', [], REPO, REPO, 'ubuntu')
        self.assertEqual(result, 1)
        self.assertEqual(missing.call_args.args, (['libgccjit-14-dev'], 'ubuntu'))


if __name__ == '__main__':
    unittest.main()
