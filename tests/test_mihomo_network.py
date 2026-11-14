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
        """The same real process survives all physical-link transitions."""
        children, states = [], []
        stop = threading.Event()
        switch = network.ProxySwitch()
        switch.request = mock.Mock(return_value={'mode': 'rule', 'tun': {'enable': True}})
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
                state_file=state, probe=probe, stop=stop, interval=0.01, debounce=0, spawn=spawn,
                switch=switch)
            self.assertEqual(result, 0)
            self.assertEqual(len(children), 1)
            self.assertTrue(all(child.poll() is not None for child in children))
            self.assertEqual(states[:2], ['offline-direct'] * 2)
            self.assertEqual(states[2:4], ['running'] * 2)
            self.assertEqual(states[4:6], ['offline-direct'] * 2)
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


class ProxySwitchTests(unittest.TestCase):
    def test_restore_previous_mode_and_tun_without_changing_groups(self):
        for mode, tun in [('rule', True), ('global', True), ('direct', False), ('rule', False)]:
            with self.subTest(mode=mode, tun=tun):
                switch = network.ProxySwitch()
                switch.request = mock.Mock(return_value={'mode': mode, 'tun': {'enable': tun}})
                switch.set_online(False)
                switch.set_online(False)
                self.assertTrue(switch.offline)
                switch.set_online(True)
                switch.set_online(True)
                self.assertFalse(switch.offline)
                self.assertEqual(switch.request.call_args_list, [
                    mock.call('GET', '/configs'),
                    mock.call('PATCH', '/configs', {'mode': 'direct', 'tun': {'enable': False}}),
                    mock.call('DELETE', '/connections'),
                    mock.call('PATCH', '/configs', {'mode': mode, 'tun': {'enable': tun}}),
                ])

    def test_failed_api_call_retries_without_losing_original_state(self):
        switch = network.ProxySwitch()
        switch.request = mock.Mock(side_effect=[{'mode': 'global', 'tun': {'enable': True}},
            OSError('temporarily unavailable'), None, None, None])
        with self.assertRaises(OSError):
            switch.set_online(False)
        switch.set_online(False)
        switch.set_online(True)
        switch.request.assert_called_with('PATCH', '/configs', {'mode': 'global', 'tun': {'enable': True}})
        self.assertEqual(sum(c.args[0] == 'GET' for c in switch.request.call_args_list), 1)


if __name__ == '__main__':
    unittest.main()
