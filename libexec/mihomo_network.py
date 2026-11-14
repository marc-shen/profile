#!/usr/bin/env python3
"""Run Mihomo only while a physical uplink is connected; preserve its config."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess as sp
import threading
import time

UPLINK_TYPES = {'wifi', 'ethernet', 'gsm', 'cdma', 'bluetooth', 'wimax'}


def state_path():
    return Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'workbench/mihomo-network.json'


def physical_connected(devices):
    for line in devices.splitlines():
        fields = line.split(':', 2)
        if len(fields) == 3 and fields[1] in UPLINK_TYPES and fields[2] in ('connected', 'connected (externally)'):
            return True
    return False


def network_available():
    """Unknown probe results must not disable an otherwise working connection."""
    env = dict(os.environ, LC_ALL='C')
    try:
        result = sp.run(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device', 'status'],
                        capture_output=True, text=True, timeout=4, env=env)
        if result.returncode:
            return None, 'networkmanager-unavailable'
        if not physical_connected(result.stdout):
            return False, 'no-physical-uplink'
        connectivity = sp.run(['nmcli', '-g', 'CONNECTIVITY', 'general'],
                              capture_output=True, text=True, timeout=4, env=env)
        if connectivity.returncode == 0 and connectivity.stdout.strip() == 'portal':
            return False, 'captive-portal'
        # "limited"/"unknown" may just mean NM's test site is blocked. Never
        # equate one failed Internet probe or a failed proxy node with no Wi-Fi.
        return True, 'uplink-connected'
    except (OSError, sp.TimeoutExpired):
        return None, 'networkmanager-unavailable'


class StableLink:
    def __init__(self, delay=10):
        self.delay = delay
        self.sample = None
        self.since = 0

    def update(self, value, now):
        if value is None or value != self.sample:
            self.sample, self.since = value, now
        if value is not None and now - self.since >= self.delay:
            return value
        return None


def stop_child(child):
    if child is None or child.poll() is not None:
        return
    child.terminate()
    try:
        child.wait(timeout=15)
    except sp.TimeoutExpired:
        child.kill()
        child.wait(timeout=5)


def supervise(command, *, state_file=None, probe=network_available,
              stop=None, interval=5, debounce=10, spawn=sp.Popen):
    stop = stop if stop is not None else threading.Event()
    state_file = state_file or state_path()
    gate = StableLink(debounce)
    child, last, exit_code = None, None, 0

    def publish(phase, reason):
        nonlocal last
        current = (phase, reason, child.pid if child else None)
        if current == last:
            return
        state_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        data = dict(phase=phase, reason=reason, core_pid=current[2], updated_at=time.time())
        temporary = state_file.with_suffix('.tmp')
        temporary.write_text(json.dumps(data) + '\n')
        temporary.chmod(0o600)
        temporary.replace(state_file)
        print(f'Mihomo network: {phase} ({reason})', flush=True)
        last = current

    try:
        while not stop.is_set():
            online, reason = probe()
            if stop.is_set():
                break
            ready = gate.update(online, time.monotonic())
            if child is not None and child.poll() is not None:
                code = child.returncode
                child = None
                if online is not False:
                    publish('failed', f'core-exited-{code}')
                    exit_code = 1
                    break  # Let systemd's restart policy handle crashes.
            if child is not None and ready is False:
                stop_child(child)
                child = None
            if child is None and (ready is True or online is None):
                child = spawn(command)
            publish('running' if child else 'waiting-network', reason)
            stop.wait(interval)
    finally:
        stop_child(child)
        child = None
        if not exit_code:
            publish('stopped', 'supervisor-stopped')
    return exit_code


def status():
    try:
        data = json.loads(state_path().read_text())
        return f"Network supervisor: {data['phase']} ({data['reason']})"
    except (OSError, ValueError, KeyError):
        return 'Network supervisor: no runtime state yet'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('a Mihomo command is required after --')
    stop = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stop.set())
    return supervise(command, stop=stop)


if __name__ == '__main__':
    raise SystemExit(main())
