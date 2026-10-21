#!/usr/bin/env python3
"""Read installed receipts and package metadata without updating an environment."""
import argparse,datetime,json,os,platform,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--prefix',type=Path,default=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software'))))
p.add_argument('--output',type=Path)
p.add_argument('--system',action='store_true',help='Also list packages owned by the system package manager')
a=p.parse_args();root=a.prefix.expanduser();result={'generated_at':datetime.datetime.now().astimezone().isoformat(),'system':platform.platform(),'root':str(root),'apps':[],'plugins':{},'uv_tools':[]}
def read(path):return json.loads(path.read_text())
for parent in sorted((root/'apps').iterdir()):
 if not parent.is_dir():continue
 current=parent/'current'
 for app in sorted(parent.iterdir()):
  if app.is_symlink() or not app.is_dir():continue
  item={'name':parent.name,'directory':str(app),'active':current.is_symlink() and current.resolve()==app.resolve()}
  for name in ['receipt.json','migration.json']:
   if (app/name).is_file():item[name]=read(app/name)
  packages=[]
  for prefix in [app/'.pixi/envs/default',app/'prefix']:
   if (prefix/'conda-meta').is_dir():
    for metadata in sorted((prefix/'conda-meta').glob('*.json')):
     d=read(metadata);packages.append({k:d.get(k) for k in ['name','version','build','depends','channel']})
  if packages:item['packages']=packages
  result['apps'].append(item)
plugins=root/'share/zsh/plugins-installed.json'
if plugins.exists():result['plugins']=read(plugins)
uv=root/'data/uv/tools'
if uv.exists():
 for tool in sorted(uv.iterdir()):
  if tool.is_dir() and (tool/'uv-receipt.toml').exists():
   result['uv_tools'].append({'name':tool.name,'path':str(tool),'receipt':(tool/'uv-receipt.toml').read_text()})
if a.system:
 if platform.system()=='Darwin':
  brew=shutil.which('brew') or ('/opt/homebrew/bin/brew' if Path('/opt/homebrew/bin/brew').exists() else '/usr/local/bin/brew')
  query=subprocess.run([brew,'list','--versions'],capture_output=True,text=True)
  result['system_packages']=query.stdout.splitlines()
  if query.returncode:result['system_inventory_warning']=query.stderr.strip()
 elif shutil.which('rpm'):
  result['system_packages']=subprocess.check_output(['rpm','-qa','--qf','%{NAME} %{VERSION}-%{RELEASE}\n'],text=True).splitlines()
 elif shutil.which('dpkg-query'):
  result['system_packages']=subprocess.check_output(['dpkg-query','-W','-f=${Package} ${Version}\n'],text=True).splitlines()
 elif shutil.which('pacman'):
  result['system_packages']=subprocess.check_output(['pacman','-Q'],text=True).splitlines()
text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
if a.output:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(text);print(a.output)
else:print(text,end='')
