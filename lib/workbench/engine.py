"""Plan and execute explicit argv commands with serialized writes and run receipts."""
from contextlib import contextmanager
import datetime
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
from .registry import order, supported

READ_ONLY = {'list', 'check', 'status', 'logs', 'plan', 'show'}


def command(spec, action, args, repo, root, platform):
    values = {'python': sys.executable, 'repo': str(repo), 'module': str(spec['_directory']),
              'root': str(root), 'platform': platform}
    entry = spec.get('entrypoints', {}).get(platform, spec['entrypoint'])
    return [part.format(**values) for part in entry] + [action, *args]


def plan(modules, name, action, args, repo, root, platform, dependencies=True):
    if name not in modules:
        raise RuntimeError('Unknown module: ' + name)
    spec = modules[name]
    if action not in spec['actions']:
        raise RuntimeError(name + ': unsupported action ' + action)
    names = order(modules, [name]) if dependencies and action in ('install', 'update') else [name]
    steps = []
    for item in names:
        operation = action if item == name else 'install'
        module = modules[item]
        if operation not in module['actions'] or not supported(module, operation, platform):
            raise RuntimeError(f'{item} {operation} is not supported on {platform}')
        arguments = args if item == name else []
        steps.append(dict(module=item, action=operation,
                          command=command(module, operation, arguments, repo, root, platform)))
    return steps


@contextmanager
def lock(root):
    path = root / 'data/workbench/operation.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another workbench operation is running.')
        yield


def execute(steps, repo, root, platform):
    env = dict(os.environ, SOFTWARE_HOME=str(root), SOFTWARE_USER_HOME=str(root),
               WORKBENCH_HOME=str(repo), PROFILE_PLATFORM=platform, PROFILE_PYTHON=sys.executable,
               PYTHONDONTWRITEBYTECODE='1')
    env['PYTHONPATH'] = str(repo / 'lib') + os.pathsep + env.get('PYTHONPATH', '')
    env['PATH'] = str(root / 'bin') + os.pathsep + env.get('PATH', os.defpath)
    if platform == 'macos': env['PATH'] = str(root / 'bin') + ':/opt/homebrew/bin:/usr/local/bin:' + env['PATH']
    if all(step['action'] in READ_ONLY for step in steps):
        codes = [subprocess.run(step['command'], env=env).returncode for step in steps]
        return max((code if code >= 0 else 128 - code for code in codes), default=0)
    if os.geteuid() == 0:
        raise RuntimeError('Run as the target user; platform installers request sudo only where needed.')
    with lock(root):
        stamp = datetime.datetime.now().astimezone().strftime('%Y%m%d-%H%M%S-%f')
        directory = root / 'data/workbench/runs'
        directory.mkdir(parents=True, exist_ok=True)
        receipt = directory / (stamp + '.json')
        log = root / 'logs' / ('workbench-' + stamp + '.log')
        log.parent.mkdir(parents=True, exist_ok=True)
        record = dict(schema=1, platform=platform, started_at=stamp, status='running', log=str(log), steps=[])
        def save():
            temporary = receipt.with_suffix('.tmp')
            temporary.write_text(json.dumps(record, indent=2) + '\n')
            temporary.replace(receipt)
        save()
        try:
            with log.open('w') as stream:
                log.chmod(0o600)
                for step in steps:
                    print(f'-> {step["module"]} {step["action"]}', flush=True)
                    # Do not store arbitrary arguments: they may contain private URLs/tokens.
                    progress = dict(module=step['module'], action=step['action'], status='running')
                    record['steps'].append(progress); save()
                    process = subprocess.Popen(step['command'], env=env, stdout=subprocess.PIPE,
                                               stderr=subprocess.STDOUT, text=True)
                    try:
                        for line in process.stdout:
                            print(line, end='', flush=True); stream.write(line); stream.flush()
                        code = process.wait()
                    finally:
                        process.stdout.close()
                        if process.poll() is None:
                            process.terminate(); process.wait()
                    progress.update(returncode=code, status='ok' if code == 0 else 'failed')
                    if code:
                        record['status'] = 'pending' if code == 2 else 'failed'; save()
                        print('Stopped at this step; rerun the same command after resolving it. Log:', log)
                        return code
            record['status'] = 'ok'; save()
            print('Completed. Run record:', receipt)
            return 0
        except BaseException:
            record['status'] = 'interrupted'; save()
            raise
