#!/usr/bin/env python3
"""Build upstream Environment Modules with private Tcl on read-only Linux systems."""
import argparse, json, os, shlex, shutil, hashlib
from pathlib import Path
import software as s
p=argparse.ArgumentParser();p.add_argument('--prefix',type=Path,default=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software'))));a=p.parse_args();root=a.prefix.expanduser().absolute()
os.environ['PIXI_CACHE_DIR']=str(root/'cache/pixi')
meta=root/'downloads/modules-latest.json';s.fetch('https://api.github.com/repos/cea-hpc/modules/releases/latest',meta)
d=json.loads(meta.read_text());version=d['tag_name'].lstrip('v')
asset=next(x for x in d['assets'] if x['name']=='modules-'+version+'.tar.gz')
archive=root/'downloads/archives'/asset['name']
if not archive.exists():s.fetch(asset['browser_download_url'],archive)
compiler={'linux-64':'gcc_linux-64','linux-aarch64':'gcc_linux-aarch64'}[s.host_platform()]
# Modules' TEA extension build needs tclConfig.sh; conda-forge Tcl 9 packages omit it.
# Keep an ABI compatibility range, not an exact version pin.
work,_=s.resolve(root,'modules',{'tk':'>=8.6,<9',compiler:'*','make':'*'})
app=s.install_environment(root,'modules',version,work,reinstall=True);s.activation(root,app)
source=root/'build'/('modules-'+version+'-'+s.STAMP);source.mkdir(parents=True)
s.run(['tar','-xzf',archive,'--strip-components=1','-C',source]);env=app/'.pixi/envs/default'
tcl_config=next(env.rglob('tclConfig.sh')).parent
tcl_include=next((env/'include').rglob('tcl.h')).parent
flags=['--prefix='+str(app),'--etcdir='+str(root/'config/modules'),'--with-tcl='+str(tcl_config),'--with-tclinclude='+str(tcl_include),'--with-tclsh='+str(env/'bin/tclsh'),'--with-modulepath='+str(root/'share/modulefiles'),'--disable-set-binpath','--disable-example-modulefiles']
script=source/'build-profile.sh';script.write_text('#!/bin/bash\nset -euo pipefail\n. '+shlex.quote(str(app/'activate.sh'))+'\ncd '+shlex.quote(str(source))+'\nexport LDFLAGS='+shlex.quote('-L'+str(env/'lib')+' -Wl,-rpath,'+str(env/'lib'))+'\n'+shlex.join(['./configure',*flags])+'\nmake -j4\nmake install\n')
s.run(['bash',script]);s.run(['bash','-c','. '+shlex.quote(str(app/'init/bash'))+'; module --version'])
s.receipt(app,dict(name='modules',version=version,backend='source',url=asset['browser_download_url'],source_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),lock_sha256=hashlib.sha256((app/'pixi.lock').read_bytes()).hexdigest()))
s.atomic_link(app,root/'apps/modules/current',root)
s.atomic_link(root/'apps/modules/current/init',root/'config/modules/init',root)
s.atomic_link(root/'apps/modules/current/bin/modulecmd',root/'bin/modulecmd',root)
