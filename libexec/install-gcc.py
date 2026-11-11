#!/usr/bin/env python3
"""Optional GCC/G++/GFortran toolchain, isolated and selected through module."""
import argparse,os,json,hashlib,shlex
from pathlib import Path
import software as s
p=argparse.ArgumentParser();p.add_argument('--prefix',type=Path,default=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software'))));a=p.parse_args();root=a.prefix.expanduser().absolute()
os.environ['PIXI_CACHE_DIR']=str(root/'cache/pixi')
platform=s.host_platform()
if platform not in ['linux-64','linux-aarch64']:raise SystemExit('This optional recipe is for Linux GCC. macOS uses Apple Clang or Homebrew GCC modules.')
names=['gcc_'+platform,'gxx_'+platform,'gfortran_'+platform]
work,packages=s.resolve(root,'gcc',{name:'*' for name in names});version=next(x['version'] for x in packages if x['name']==names[0])
app=s.install_environment(root,'gcc',version,work);s.activation(root,app)
triplet='x86_64-conda-linux-gnu' if platform=='linux-64' else 'aarch64-conda-linux-gnu'
for name,native in [('gcc','gcc'),('cc','gcc'),('g++','g++'),('c++','g++'),('gfortran','gfortran')]:
 exe=s.wrapper(app,name,app/'.pixi/envs/default/bin'/(triplet+'-'+native));s.run([exe,'--version'])
module=root/'share/modulefiles/gcc'/app.name;module.parent.mkdir(parents=True,exist_ok=True)
module.write_text('#%Module1.0\nmodule-whatis "GCC/G++/GFortran '+version+'"\nconflict gcc\nsource-sh bash {'+str(app/'activate.sh')+'}\nprepend-path PATH {'+str(app/'launch')+'}\npushenv CC gcc\npushenv CXX g++\npushenv FC gfortran\n')
s.receipt(app,dict(name='gcc',version=version,backend='pixi',dependencies={name:'*' for name in names},lock_sha256=hashlib.sha256((app/'pixi.lock').read_bytes()).hexdigest()))
s.atomic_link(app,root/'apps/gcc/current',root)
s.atomic_link(module,root/'share/modulefiles/gcc/current',root)
# Stable command entry points do not globally activate compiler environment variables.
for name in ['gcc','cc','g++','c++','gfortran']:s.atomic_link(root/'apps/gcc/current/launch'/name,root/'bin'/name,root)
