"""Verify that a failed smoke test never replaces a working command."""
import importlib.util,json,tempfile,unittest,subprocess
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('software',Path(__file__).resolve().parents[1]/'scripts/software.py')
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
class InstallTests(unittest.TestCase):
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
   with patch.object(s,'output',return_value='export PATH="/app/bin:/__PROFILE_CALLER_PATH__"\n'):
    s.activation(root,root)
   result=subprocess.check_output(['/bin/bash','-c','. "$1/activate.sh"; printf "%s" "$PATH"','bash',str(root)],env={'PATH':'/caller/bin'},text=True)
   self.assertEqual(result,'/app/bin:/caller/bin')
if __name__=='__main__':unittest.main()
