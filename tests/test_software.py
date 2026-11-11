"""Verify that a failed smoke test never replaces a working command."""
import importlib.util,json,tempfile,unittest,subprocess,shutil,types,os
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('software',Path(__file__).resolve().parents[1]/'libexec/software.py')
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
class InstallTests(unittest.TestCase):
 def test_interrupted_appimage_download_resumes_without_replacing_old_archive(self):
  with tempfile.TemporaryDirectory() as t:
   archive=Path(t)/'tool.AppImage';archive.write_bytes(b'old verified archive')
   temporary=archive.with_name(archive.name+'.download');temporary.write_bytes(b'partial')
   with patch.object(s,'run',side_effect=subprocess.CalledProcessError(92,['curl'])) as download:
    with self.assertRaises(subprocess.CalledProcessError):s.fetch('https://example.invalid/tool.AppImage',archive)
   self.assertIn('--continue-at',download.call_args.args[0])
   self.assertEqual(download.call_args.args[0][-1],temporary)
   self.assertEqual(archive.read_bytes(),b'old verified archive')
   self.assertEqual(temporary.read_bytes(),b'partial')

 def test_failed_official_node_install_keeps_pixi_current(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t).resolve();old=root/'apps/node/26.13.0';old.mkdir(parents=True)
   s.atomic_link(old,root/'apps/node/current',root)
   nvm=root/'apps/nvm/0.41.0';nvm.mkdir(parents=True)
   (nvm/'nvm.sh').write_text('''nvm() {
 test "$NVM_NODEJS_ORG_MIRROR" = https://nodejs.org/dist || return 91
 test -z "${NVM_INSTALL_THIRD_PARTY_HOOK:-}" || return 92
 test "$1" = install || return 93
 return 0
}
''')
   for name in ['nvm-exec','bash_completion']:(nvm/name).touch()
   binaries=root/'data/nvm/versions/node/v26.13.0/bin';binaries.mkdir(parents=True)
   for name,body in [('node','echo v26.13.0'),('npm','exit 7'),('npx','exit 0')]:
    path=binaries/name;path.write_text('#!/bin/sh\n'+body+'\n');path.chmod(0o755)
   with patch.dict(os.environ,{'NVM_INSTALL_THIRD_PARTY_HOOK':'unexpected-downloader'}):
    with self.assertRaises(subprocess.CalledProcessError):
     s.tool(root,'node',{'backend':'nvm','version':'26.13.0','nvm_version':'0.41.0','commands':['node','npm','npx']})
   self.assertEqual((root/'apps/node/current').resolve(),old)
   self.assertFalse((root/'bin/node').exists())
   self.assertFalse((root/'apps/node/26.13.0-nvm/receipt.json').exists())

 def test_failed_lsp_handshake_keeps_current(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t).resolve();old=root/'apps/lsp-tool/1';new=root/'apps/lsp-tool/2';work=root/'work'
   for p in [old,new,work]:p.mkdir(parents=True)
   (work/'pixi.lock').write_text('new lock')
   s.atomic_link(old,root/'apps/lsp-tool/current',root)
   def failed_probe(_):raise RuntimeError('invalid initialize response')
   with patch.dict('sys.modules',{'lsp_probe':types.SimpleNamespace(probe=failed_probe)}),patch.object(s,'resolve',return_value=(work,[{'name':'tool','version':'2'}])),patch.object(s,'install_environment',return_value=new),patch.object(s,'activation'):
    with self.assertRaises(RuntimeError):s.tool(root,'lsp-tool',{'package':'tool','commands':['tool'],'lsp':['tool','--stdio']})
   self.assertEqual((root/'apps/lsp-tool/current').resolve(),old)
   self.assertFalse((new/'receipt.json').exists())
 def test_failed_smoke_test_keeps_current(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t).resolve();old=root/'apps/tool/1';new=root/'apps/tool/2';work=root/'work'
   for p in [old,new,work]:p.mkdir(parents=True)
   (work/'pixi.lock').write_text('new lock')
   s.atomic_link(old,root/'apps/tool/current',root)
   with patch.object(s,'resolve',return_value=(work,[{'name':'tool','version':'2'}])),patch.object(s,'install_environment',return_value=new),patch.object(s,'activation'),patch.object(s,'run',side_effect=subprocess.CalledProcessError(1,['tool'])):
    with self.assertRaises(subprocess.CalledProcessError):s.tool(root,'tool',{'package':'tool','commands':['tool']})
   self.assertEqual((root/'apps/tool/current').resolve(),old)
   self.assertFalse((new/'receipt.json').exists())
 def test_activation_preserves_callers_path(self):
  with tempfile.TemporaryDirectory() as t:
   root=Path(t)
   def hook(args,env):
    self.assertIsNotNone(shutil.which('sh',path=env['PATH']))
    return 'export PATH="/app/bin:'+env['PATH']+'"\n'
   with patch.object(s,'output',side_effect=hook):
    s.activation(root,root)
   result=subprocess.check_output(['/bin/bash','-c','. "$1/activate.sh"; printf "%s" "$PATH"','bash',str(root)],env={'PATH':'/caller/bin'},text=True)
   self.assertEqual(result,'/app/bin:/caller/bin')
if __name__=='__main__':unittest.main()
