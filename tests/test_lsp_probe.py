"""Validate real stdio framing, protocol failure and bounded noisy-server timeout."""
import importlib.util
from pathlib import Path
import sys
import time
import unittest

spec = importlib.util.spec_from_file_location('lsp_probe', Path(__file__).resolve().parents[1] / 'scripts/lsp_probe.py')
probe_module = importlib.util.module_from_spec(spec); spec.loader.exec_module(probe_module)

SERVER = r'''
import sys,json,time
def send(message):
 data=json.dumps(dict(jsonrpc='2.0',**message)).encode()
 sys.stdout.buffer.write(('Content-Length: %d\r\n\r\n'%len(data)).encode()+data)
 sys.stdout.buffer.flush()
while True:
 line=sys.stdin.buffer.readline()
 if not line:break
 length=int(line.split(b':',1)[1]);sys.stdin.buffer.readline()
 request=json.loads(sys.stdin.buffer.read(length))
 if request['method']=='initialize':
  if sys.argv[1]=='noise':
   while True:
    send({'method':'window/logMessage','params':{'type':3,'message':'busy'}});time.sleep(.001)
  result={'capabilities':None} if sys.argv[1]=='invalid' else {'capabilities':{},'serverInfo':{'name':'test-server'}}
  send({'id':request['id'],'result':result})
 elif request['method']=='shutdown':send({'id':request['id'],'result':None})
 elif request['method']=='exit':break
'''

class ProbeTests(unittest.TestCase):
    def test_initialize_and_shutdown(self):
        result = probe_module.probe([sys.executable, '-u', '-c', SERVER, 'ok'], timeout=2)
        self.assertEqual(result, {'name': 'test-server'})
    def test_invalid_capabilities_fail(self):
        with self.assertRaisesRegex(RuntimeError, 'capabilities'):
            probe_module.probe([sys.executable, '-u', '-c', SERVER, 'invalid'], timeout=2)
    def test_notifications_do_not_extend_deadline(self):
        start = time.monotonic()
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            probe_module.probe([sys.executable, '-u', '-c', SERVER, 'noise'], timeout=.2)
        self.assertLess(time.monotonic() - start, 4)

if __name__ == '__main__': unittest.main()
