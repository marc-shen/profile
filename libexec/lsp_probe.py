"""Bounded stdio initialize/shutdown probe; never attaches to an editor's server."""
import json
import os
from pathlib import Path
import queue
import signal
import subprocess as sp
import tempfile
import threading
import time

def probe(command, timeout=30):
    with tempfile.TemporaryDirectory(prefix='profile-lsp-') as directory, tempfile.TemporaryFile() as errors:
        process = sp.Popen(list(map(str, command)), stdin=sp.PIPE, stdout=sp.PIPE,
                           stderr=errors, cwd=directory, start_new_session=True)
        messages = queue.Queue()
        def reader():
            try:
                while True:
                    length = None
                    while True:
                        line = process.stdout.readline()
                        if not line: raise EOFError('language server closed stdout')
                        if line.lower().startswith(b'content-length:'): length = int(line.split(b':', 1)[1])
                        if line in (b'\r\n', b'\n') and length is not None: break
                    data = process.stdout.read(length)
                    messages.put(json.loads(data))
            except Exception as error: messages.put(error)
        thread = threading.Thread(target=reader, daemon=True); thread.start()
        def send(message):
            data = json.dumps(dict(jsonrpc='2.0', **message)).encode()
            process.stdin.write(('Content-Length: %d\r\n\r\n' % len(data)).encode() + data)
            process.stdin.flush()
        def response(identifier):
            deadline = time.monotonic() + timeout
            while True:
                if time.monotonic() >= deadline: raise TimeoutError('language server response deadline exceeded')
                item = messages.get(timeout=max(.01, deadline - time.monotonic()))
                if isinstance(item, Exception): raise item
                if item.get('id') == identifier and ('result' in item or 'error' in item):
                    if 'error' in item: raise RuntimeError(str(item['error']))
                    return item['result']
                # Reply to requests such as workspace/configuration while probing.
                if 'method' in item and 'id' in item:
                    result = [None] * len(item.get('params', {}).get('items', [])) if item['method'] == 'workspace/configuration' else None
                    send({'id': item['id'], 'result': result})
        try:
            uri = Path(directory).as_uri()
            send({'id': 1, 'method': 'initialize', 'params': {'processId': os.getpid(),
                  'rootUri': uri, 'rootPath': directory, 'capabilities': {},
                  'workspaceFolders': [{'uri': uri, 'name': 'profile-probe'}]}})
            result = response(1)
            if not isinstance(result, dict) or not isinstance(result.get('capabilities'), dict):
                raise RuntimeError('initialize did not return server capabilities')
            send({'method': 'initialized', 'params': {}})
            send({'id': 2, 'method': 'shutdown', 'params': None})
            response(2)
            send({'method': 'exit'})
            process.wait(timeout=5)
            if process.returncode != 0: raise RuntimeError('server exited with ' + str(process.returncode))
            return result.get('serverInfo', {'capabilities': sorted(result['capabilities'])})
        except Exception as error:
            errors.seek(0)
            detail = errors.read(4000).decode(errors='replace')
            raise RuntimeError('LSP probe failed for %s: %s\n%s' % (command[0], error, detail)) from error
        finally:
            # Only this probe's own process group, never any running Emacs/LSP.
            try: os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError: pass
            try: process.wait(timeout=2)
            except sp.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); process.wait()
            thread.join(timeout=2)
            process.stdin.close()
            process.stdout.close()
