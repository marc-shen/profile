"""Exercise the public framework, extension protocol, migration and offline planning."""
import json
import os
from pathlib import Path
import subprocess as sp
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'lib'))
from workbench.platforms import detect
from workbench.registry import discover
from workbench.cli import load_profile
from workbench.engine import plan


class FrameworkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='framework test ')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.root = self.home / 'Software with spaces'
        self.env = dict(os.environ, HOME=str(self.home), SOFTWARE_HOME=str(self.root),
                        SOFTWARE_USER_HOME=str(self.root), WORKBENCH_HOME=str(REPO), PYTHONDONTWRITEBYTECODE='1')

    def ctl(self, *args):
        return sp.run([sys.executable, str(REPO / 'bin/workbench'), *args], env=self.env, text=True, capture_output=True)

    def bootstrap(self, *args):
        return sp.run(['bash', str(REPO / 'bootstrap.sh'), *args], env=self.env, text=True, capture_output=True)

    def extension(self, name='custom', requires=()):
        folder = self.root / 'extensions' / name
        folder.mkdir(parents=True)
        spec = dict(schema=1, name=name, description='Extension', platforms=['macos','steamdeck','fedora','ubuntu','debian'],requires=list(requires),entrypoint=['{python}','{module}/run.py'],actions={a:dict(description=a) for a in ['list','check','install','update']})
        (folder / 'module.json').write_text(json.dumps(spec))
        (folder / 'run.py').write_text('''import os,json,pathlib,sys
root=pathlib.Path(os.environ['SOFTWARE_HOME'])
if sys.argv[1] not in ['list','check']:
 with (root/'executed').open('a') as out: out.write(pathlib.Path(__file__).parent.name+'\\n')
print(json.dumps(sys.argv[1:]))
if '--fail' in sys.argv: raise SystemExit(7)
''')
        return folder

    def test_detection_covers_supported_hosts(self):
        self.assertEqual(detect('Darwin'), 'macos')
        for distro, name in [('steamos','steamdeck'),('fedora','fedora'),('ubuntu','ubuntu')]:
            self.assertEqual(detect('Linux', 'ID="'+distro+'"'),name)
        with self.assertRaises(RuntimeError): detect('Linux','ID=unknown')

    def test_every_platform_has_a_complete_read_only_install_plan(self):
        for platform in ['macos','steamdeck','fedora','ubuntu']:
            result = self.ctl('--platform',platform,'system','install','--plan','--json')
            self.assertEqual(result.returncode,0,result.stderr)
            plan=json.loads(result.stdout)
            steps=[(step['module'],step['action']) for step in plan['steps']]
            for name in ['platform','managers','tools','plugins','languages','emacs','profile','wezterm']:
                self.assertTrue(any(step[0]==name for step in steps), name)
            self.assertLess(steps.index(('managers','install')),steps.index(('tools','install')))
            self.assertLess(steps.index(('emacs','install')),steps.index(('emacs','start')))
            if platform=='steamdeck': self.assertIn(('network','apply'),steps)
            for name in ['platform','managers','tools','plugins','languages','emacs','profile','wezterm']:
                self.assertIn((name, 'check'), steps)
            self.assertGreater(steps.index(('profile','check')),steps.index(('emacs','start')))
            self.assertFalse(self.root.exists())

    def test_profile_inheritance_reuses_steps_and_rejects_cycles_and_platform_widening(self):
        folder=self.home/'profiles';folder.mkdir()
        base=dict(schema=1, platforms=['fedora'], install=[dict(module='tools',action='install')],check=[dict(module='tools',action='check')])
        child=dict(schema=1, platforms=['fedora'],extends=['base'],install=[dict(module='emacs',action='install')])
        (folder/'base.json').write_text(json.dumps(base))
        (folder/'child.json').write_text(json.dumps(child))
        resolved=load_profile(self.home,'child')
        self.assertEqual([item['module'] for item in resolved['install']],['tools','emacs'])
        self.assertEqual(resolved['check'],base['check'])
        child['platforms'].append('macos')
        (folder/'child.json').write_text(json.dumps(child))
        with self.assertRaisesRegex(RuntimeError,'parent does not support'):
            load_profile(self.home,'child')
        child['platforms']=['fedora'];child['extends']=['child']
        (folder/'child.json').write_text(json.dumps(child))
        with self.assertRaisesRegex(RuntimeError,'cyclic'):
            load_profile(self.home,'child')

    def test_platform_entrypoints_override_only_the_selected_platform(self):
        folder=self.extension()
        path=folder/'module.json';spec=json.loads(path.read_text())
        spec['entrypoints']={'macos':['{python}','{module}/macos.py']}
        path.write_text(json.dumps(spec))
        modules=discover(REPO,self.root)
        mac=plan(modules,'custom','install',[],REPO,self.root,'macos')
        linux=plan(modules,'custom','install',[],REPO,self.root,'fedora')
        self.assertEqual(mac[-1]['command'][1],str(folder/'macos.py'))
        self.assertEqual(linux[-1]['command'][1],str(folder/'run.py'))
        self.assertFalse((self.root/'executed').exists())

    def test_plan_rejects_mutation_for_a_different_host(self):
        other='ubuntu' if detect()!='ubuntu' else 'macos'
        result=self.ctl('--platform',other,'tools','install','fd')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.root.exists())

    def test_bootstrap_only_sets_up_base_and_is_repeatable(self):
        rc=self.home/'.bashrc';rc.write_text('export KEEP_ME=yes\n');rc.chmod(0o600)
        self.assertEqual(self.bootstrap('--plan').returncode,0)
        self.assertFalse(self.root.exists())
        result=self.bootstrap('--offline');self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((self.root/'bin/workbench').exists())
        self.assertTrue((self.root/'extensions').is_dir())
        self.assertFalse((self.home/'.emacs.d').exists())
        before=rc.stat().st_mtime_ns
        self.assertEqual(self.bootstrap('--offline').returncode,0)
        self.assertEqual(rc.stat().st_mtime_ns,before)
        self.assertEqual(rc.stat().st_mode & 0o777,0o600)
        self.assertIn('KEEP_ME',rc.read_text())
        result=sp.run([self.root/'bin/workbench','list'],env=self.env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_migrates_old_local_modules_and_preserves_unrelated_commands(self):
        folder=self.root/'config/manage.d';folder.mkdir(parents=True)
        script=folder/'private.sh';script.write_text('#!/bin/sh\n# manage-actions: list check install update\necho migrated "$@"\n');script.chmod(0o755)
        binary=self.root/'bin/manage';binary.parent.mkdir();binary.write_text('unrelated')
        result=self.bootstrap('--offline');self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(script.exists())
        self.assertTrue(list((self.root/'backups').glob('bootstrap-*/private.sh')))
        self.assertEqual(binary.read_text(),'unrelated')
        result=self.ctl('private','check');self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('migrated check',result.stdout)

    def test_rename_retires_only_the_managed_old_command(self):
        binary=self.root/'bin/profilectl';binary.parent.mkdir(parents=True)
        binary.write_text('#!/bin/sh\n# Managed by profile bootstrap\necho old\n')
        result=self.bootstrap('--offline')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(binary.exists())
        self.assertTrue((self.root/'bin/workbench').is_file())
        self.assertTrue(list((self.root/'backups').glob('bootstrap-*/profilectl')))
        binary.write_text('#!/bin/sh\necho independent command\n')
        self.assertEqual(self.bootstrap('--offline').returncode,0)
        self.assertTrue(binary.exists())

    def test_rename_replaces_the_owned_bash_completion_block(self):
        rc=self.home/'.bashrc'
        rc.write_text('export KEEP_ME=yes\n\n# profilectl completion (Bash only)\n'
                      '[ -z "${BASH_VERSION:-}" ] || . /old/profile/config/shell/completions/profilectl.bash\n')
        result=self.bootstrap('--offline')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn('/old/profile/',rc.read_text())
        self.assertIn('KEEP_ME',rc.read_text())
        self.assertEqual(rc.read_text().count('# workbench completion'),1)
        before=rc.stat().st_mtime_ns
        self.assertEqual(self.bootstrap('--offline').returncode,0)
        self.assertEqual(rc.stat().st_mtime_ns,before)

    def test_discovery_help_completion_and_plan_never_execute_handlers(self):
        self.extension()
        for args in [('list',),('custom','--help'),('custom','install','--help'),('--complete','modules'),('--complete','actions','custom'),('custom','install','--plan')]:
            result=self.ctl(*args);self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse((self.root/'executed').exists())
        self.assertIn('custom:Extension',self.ctl('--complete','modules').stdout)

    def test_dependencies_arguments_failure_receipts_and_rerun(self):
        self.extension('first');self.extension('second',['first'])
        result=self.ctl('second','install','a path','$(touch never-run)','--fail')
        self.assertEqual(result.returncode,7,result.stderr)
        self.assertEqual((self.root/'executed').read_text().splitlines(),['first','second'])
        records=list((self.root/'data/workbench/runs').glob('*.json'))
        state=json.loads(records[0].read_text());self.assertEqual(state['status'],'failed')
        self.assertNotIn('$(touch',records[0].read_text())
        self.assertIn('a path',result.stdout)
        self.assertEqual(self.ctl('second','install').returncode,0)

    def test_duplicate_and_cyclic_modules_are_rejected(self):
        self.extension('tools')
        self.assertIn('Duplicate module',self.ctl('list').stderr)
        import shutil
        shutil.rmtree(self.root/'extensions/tools')
        self.extension('a',['b']);self.extension('b',['a'])
        self.assertIn('Dependency cycle',self.ctl('list').stderr)

    def test_scaffold_is_immediately_usable(self):
        result=self.ctl('modules','create','my-app');self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.ctl('my-app','check').returncode,1)
        self.assertEqual(self.ctl('my-app','install').returncode,0)
        self.assertEqual(self.ctl('my-app','check').returncode,0)
        self.assertIn('my-app',self.ctl('--complete','modules').stdout)

    def test_every_builtin_has_metadata_help_and_read_only_list(self):
        for name,spec in discover(REPO,self.root).items():
            for action in spec['actions']:
                result=self.ctl(name,action,'--help')
                self.assertEqual(result.returncode,0,(name,action,result.stderr))
                self.assertFalse(self.root.exists())
            result=self.ctl(name,'list')
            self.assertEqual(result.returncode,0,(name,result.stderr))
            self.assertFalse(self.root.exists())

    def test_invalid_selection_fails_before_dependency_install(self):
        result=self.ctl('plugins','install','nonexistent')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.root.exists())


if __name__=='__main__': unittest.main()
