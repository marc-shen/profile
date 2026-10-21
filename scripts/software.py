#!/usr/bin/env python3
"""Versioned installs: latest compatible stable versions, recorded locks, explicit updates."""
import argparse, datetime, hashlib, json, os, platform, shlex, shutil, subprocess as sp, tarfile
from pathlib import Path
REPO=Path(__file__).resolve().parents[1]
STAMP=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
def run(args, **kw):
 print('+', shlex.join(map(str,args)),flush=True)
 return sp.run(list(map(str,args)),check=True,**kw)
def output(args,**kw):return sp.check_output(list(map(str,args)),text=True,**kw)
def fetch(url,dest):
 dest.parent.mkdir(parents=True,exist_ok=True)
 options=['curl','-4','-fsSL','--retry','4','--retry-all-errors','--connect-timeout','20','--max-time','1800']
 if os.environ.get('PROFILE_DOWNLOAD_PROXY') and 'github.com/' in url and 'api.github.com' not in url:
  options+=['--proxy',os.environ['PROFILE_DOWNLOAD_PROXY']]
 if url.endswith(('.tar.gz','.tar.xz')) and dest.exists():options+=['--continue-at','-']
 temporary=dest if url.endswith(('.tar.gz','.tar.xz')) else dest.with_name(dest.name+'.download')
 run([*options,url,'-o',temporary])
 if temporary!=dest:os.replace(temporary,dest)
def host_platform():return {('Darwin','arm64'):'osx-arm64',('Darwin','x86_64'):'osx-64',('Linux','x86_64'):'linux-64',('Linux','aarch64'):'linux-aarch64'}[(platform.system(),platform.machine())]
def atomic_link(src,dest,root):
 dest.parent.mkdir(parents=True,exist_ok=True)
 if dest.is_symlink() and dest.resolve()==src.resolve():return
 if dest.exists() or dest.is_symlink():
  backup=root/'backups'/('switch-'+STAMP)/dest.relative_to(root)
  backup.parent.mkdir(parents=True,exist_ok=True)
  if not backup.exists() and not backup.is_symlink():
   if dest.is_symlink():backup.symlink_to(os.readlink(dest))
   elif dest.is_file():shutil.copy2(dest,backup)
   else:raise RuntimeError('Refusing to replace directory: '+str(dest))
 temporary=dest.with_name(dest.name+'.new-'+str(os.getpid()))
 temporary.symlink_to(os.path.relpath(src,dest.parent));os.replace(temporary,dest)
def receipt(app,data):
 data.update(installed_at=STAMP,platform=host_platform())
 (app/'receipt.json').write_text(json.dumps(data,indent=2)+'\n')
def manager(root,name):
 upstream={'pixi':'prefix-dev/pixi','uv':'astral-sh/uv'}[name]
 metadata=root/'downloads'/(name+'-latest.json')
 if not os.environ.get('PROFILE_USE_RELEASE_CACHE'):
  fetch('https://api.github.com/repos/'+upstream+'/releases/latest',metadata)
 release=json.loads(metadata.read_text());version=release['tag_name'].removeprefix('v')
 arch={'arm64':'aarch64','aarch64':'aarch64','x86_64':'x86_64'}[platform.machine()]
 target=arch+('-apple-darwin' if platform.system()=='Darwin' else '-unknown-linux-musl')
 asset=name+'-'+target+'.tar.gz';assets={a['name']:a['browser_download_url'] for a in release['assets']}
 app=root/'apps'/name/version
 if not (app/'receipt.json').exists():
  archive=root/'downloads/archives'/(name+'-'+version+'-'+target+'.tar.gz')
  checksum=archive.with_suffix(archive.suffix+'.sha256')
  if not (os.environ.get('PROFILE_USE_RELEASE_CACHE') and checksum.exists()):fetch(assets[asset+'.sha256'],checksum)
  expected=checksum.read_text().split()[0]
  if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:fetch(assets[asset],archive)
  if hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:raise RuntimeError('SHA256 mismatch: '+str(archive))
  (app/'bin').mkdir(parents=True,exist_ok=True)
  with tarfile.open(archive) as tar:
   for command in (['uv','uvx'] if name=='uv' else ['pixi']):
    member=next(m for m in tar.getmembers() if m.isfile() and Path(m.name).name==command)
    (app/'bin'/command).write_bytes(tar.extractfile(member).read());(app/'bin'/command).chmod(0o755)
  run([app/'bin'/name,'--version']);receipt(app,dict(name=name,version=version,backend='upstream',url=assets[asset],sha256=expected))
 atomic_link(app,root/'apps'/name/'current',root)
 for command in (['uv','uvx'] if name=='uv' else ['pixi']):atomic_link(root/'apps'/name/'current/bin'/command,root/'bin'/command,root)
 return app

def resolve(root,name,dependencies):
 work=root/'build/resolve'/(name+'-'+STAMP+'-'+str(os.getpid()));work.mkdir(parents=True,exist_ok=True)
 manifest='[workspace]\nname = '+json.dumps(name)+'\nchannels = ["conda-forge"]\nplatforms = ['+json.dumps(host_platform())+']\n\n[dependencies]\n'
 manifest+=''.join(json.dumps(k)+' = '+json.dumps(v)+'\n' for k,v in dependencies.items())
 (work/'pixi.toml').write_text(manifest)
 pixi=root/'bin/pixi';run([pixi,'lock','--manifest-path',work/'pixi.toml'])
 packages=json.loads(output([pixi,'list','--json','--manifest-path',work/'pixi.toml']))
 return work,packages

def install_environment(root,name,version,work,reinstall=False):
 digest=hashlib.sha256((work/'pixi.lock').read_bytes()).hexdigest();app=root/'apps'/name/version
 if app.exists():
  old=app/'receipt.json'
  if old.exists() and json.loads(old.read_text()).get('lock_sha256')==digest and not reinstall:return app
  app=app.with_name(version+'-r'+STAMP)
 app.mkdir(parents=True,exist_ok=False)
 for filename in ['pixi.toml','pixi.lock']:shutil.copy2(work/filename,app/filename)
 run([root/'bin/pixi','install','--locked','--manifest-path',app/'pixi.toml'])
 return app

def activation(root,app):
 # Generate once, so launching never writes to the shared installation.
 env=dict(os.environ,PATH='/__PROFILE_CALLER_PATH__')
 hook=output([root/'bin/pixi','shell-hook','--shell','bash','--manifest-path',app/'pixi.toml','--locked'],env=env)
 hook=hook.replace('/__PROFILE_CALLER_PATH__','${PATH}')
 (app/'activate.sh').write_text(hook)

def wrapper(app,command,binary):
 dest=app/'launch'/command;dest.parent.mkdir(exist_ok=True)
 activate='' if command=='zsh' else '. '+shlex.quote(str(app/'activate.sh'))+'\n'
 dest.write_text('#!/bin/bash\nset -e\n'+activate+'exec '+shlex.quote(str(binary))+' "$@"\n');dest.chmod(0o755)
 return dest

def tool(root,name,spec,reinstall=False):
 work,packages=resolve(root,name,{spec['package']:'*'})
 version=next(p['version'] for p in packages if p['name']==spec['package'])
 app=install_environment(root,name,version,work,reinstall);activation(root,app)
 for command in spec['commands']:
  entry=wrapper(app,command,app/'.pixi/envs/default/bin'/command);run([entry,'--version'],stdout=sp.DEVNULL)
 receipt(app,dict(name=name,version=version,backend='pixi',dependencies={spec['package']:'*'},lock_sha256=hashlib.sha256((app/'pixi.lock').read_bytes()).hexdigest(),commands=spec['commands']))
 atomic_link(app,root/'apps'/name/'current',root)
 for command in spec['commands']:atomic_link(root/'apps'/name/'current/launch'/command,root/'bin'/command,root)
 return app

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['managers','tools','update','list']);p.add_argument('names',nargs='*')
 p.add_argument('--prefix',type=Path,default=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software'))));p.add_argument('--reinstall',action='store_true')
 args=p.parse_args();root=args.prefix.expanduser().absolute();os.environ['PIXI_CACHE_DIR']=str(root/'cache/pixi')
 if args.action=='list':
  for f in sorted((root/'apps').glob('*/current/receipt.json')):
   d=json.loads(f.read_text());print(d['name'],d['version'],d['backend'],f.parent.resolve())
  return
 if args.action in ['managers','update']:
  for name in (args.names if args.action=='managers' and args.names else ['pixi','uv']):manager(root,name)
 if args.action in ['tools','update']:
  specs=json.loads((REPO/'manifests/tools.json').read_text())
  for name in (args.names or specs):tool(root,name,specs[name],args.reinstall)
if __name__=='__main__':main()
