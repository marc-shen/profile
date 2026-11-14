import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'libexec'))
import mihomo_network as network


class LinkTests(unittest.TestCase):
    def test_virtual_interfaces_do_not_count_as_uplinks(self):
        self.assertFalse(network.physical_connected(
            'tailscale0:tun:connected (externally)\nmihomo-tun:tun:connected (externally)\n'
            'lo:loopback:connected (externally)\nwlan0:wifi:disconnected'))
        for link in ('wlan0:wifi:connected', 'eth0:ethernet:connected',
                     'eth0:ethernet:connected (externally)'):
            self.assertTrue(network.physical_connected(link))

    def test_portal_pauses_but_limited_does_not(self):
        for state in ('portal', 'limited', 'unknown', 'full'):
            with self.subTest(state=state), mock.patch.object(network.sp, 'run', side_effect=[
                mock.Mock(returncode=0, stdout='wlan0:wifi:connected'),
                mock.Mock(returncode=0, stdout=state),
            ]):
                self.assertEqual(network.network_available()[0], state != 'portal')

    def test_probe_failure_does_not_disable_proxy(self):
        for failure in (FileNotFoundError(), subprocess.TimeoutExpired('nmcli', 4)):
            with mock.patch.object(network.sp, 'run', side_effect=failure):
                self.assertIsNone(network.network_available()[0])

    def test_debounce_and_unknown_reset(self):
        gate = network.StableLink(10)
        for value, now, expected in [(True, 0, None), (True, 9, None), (True, 10, True),
                                     (False, 11, None), (True, 12, None), (True, 22, True),
                                     (False, 23, None), (None, 30, None), (False, 31, None),
                                     (False, 41, False)]:
            self.assertIs(gate.update(value, now), expected)


class SupervisorTests(unittest.TestCase):
    def test_real_child_offline_reconnect_and_manual_stop(self):
        """Exercise actual process termination/recreation without changing host networking."""
        children, states = [], []
        stop = threading.Event()
        def spawn(command):
            child = subprocess.Popen(command)
            children.append(child)
            return child
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / 'state.json'
            def probe():
                if state.exists():
                    states.append(json.loads(state.read_text())['phase'])
                if len(states) >= 8:
                    stop.set()
                # Start offline, connect, disconnect, reconnect, then stop.
                online = len(states) in (2, 3, 6, 7, 8)
                return online, 'test-connected' if online else 'test-offline'
            result = network.supervise(
                [sys.executable, '-c', 'import time; time.sleep(60)'],
                state_file=state, probe=probe, stop=stop, interval=0.01, debounce=0, spawn=spawn)
            self.assertEqual(result, 0)
            self.assertEqual(len(children), 2)
            self.assertTrue(all(child.poll() is not None for child in children))
            self.assertEqual(states[:2], ['waiting-network'] * 2)
            self.assertEqual(states[2:4], ['running'] * 2)
            self.assertEqual(states[4:6], ['waiting-network'] * 2)
            self.assertEqual(json.loads(state.read_text())['phase'], 'stopped')

    def test_core_crash_returns_failure_to_systemd(self):
        child = mock.Mock(pid=42, returncode=1)
        child.poll.return_value = 1
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / 'state.json'
            result = network.supervise(['unused'], state_file=state,
                probe=lambda: (True, 'uplink-connected'), interval=0, debounce=0,
                spawn=lambda command: child)
            self.assertEqual(result, 1)
            self.assertEqual(json.loads(state.read_text())['phase'], 'failed')


if __name__ == '__main__':
    unittest.main()
