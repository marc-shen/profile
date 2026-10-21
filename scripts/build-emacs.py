#!/usr/bin/env python3
"""Build the latest stable GNU Emacs at its final prefix; do not restart a daemon."""
import argparse, hashlib, json, os, re, shlex, shutil, subprocess as sp, tarfile
from pathlib import Path
import software as s
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--prefix',type=Path,default=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software'))))
p.add_argument('--deps',choices=['system','pixi'],default='system')
p.add_argument('--source', type=Path, help='Existing clean source tree for the resolved stable release')
p.add_argument('--jobs',type=int,default=4)
a=p.parse_args();root=a.prefix.expanduser().absolute()
os.environ['PIXI_CACHE_DIR']=str(root/'cache/pixi')
index=root/'downloads/emacs-index.html'
if not (a.source and index.exists()):s.fetch('https://ftp.gnu.org/gnu/emacs/',index)
versions=set(re.findall(r'emacs-([0-9]+\.[0-9]+)\.tar\.xz',index.read_text()))
version=max(versions,key=lambda v:tuple(map(int,v.split('.'))))
archive=root/'downloads/archives'/('emacs-'+version+'.tar.xz')
if a.source:
 source=a.source.expanduser().absolute()
 if not (source/'configure').exists():raise SystemExit('Source tree lacks configure')
 actual=s.output(['git','-C',source,'describe','--tags','--exact-match']).strip()
 if actual!='emacs-'+version:raise SystemExit('Existing source is not the latest stable release tag: '+actual)
 if s.output(['git','-C',source,'status','--porcelain']).strip():raise SystemExit('Source checkout has local changes')
else:
 if not archive.exists():s.fetch('https://ftp.gnu.org/gnu/emacs/'+archive.name,archive)
 source=root/'src'/('emacs-'+version+'-release')
 if not source.exists():
  source.mkdir(parents=True)
  s.run(['tar','-xJf',archive,'--strip-components=1','-C',source])
app=root/'apps/emacs'/(version+'-r'+s.STAMP)
app.mkdir(parents=True,exist_ok=False)
build=root/'build'/('emacs-'+version+'-'+s.STAMP);build.mkdir(parents=True)
flags=['--prefix='+str(app),'--without-pgtk','--with-x-toolkit=gtk3','--with-modules','--with-tree-sitter','--with-gnutls','--without-compress-install']
if a.deps=='pixi':
 platform=s.host_platform();compiler={'linux-64':'linux-64','linux-aarch64':'linux-aarch64'}[platform]
 names=['autoconf','automake','cmake','dbus','expat','giflib','glib','gnutls','gtk3','libjpeg-turbo','libpng','librsvg','libtiff','libtool','libtree-sitter','libvterm','libwebp','libxml2','libxml2-devel','make','ncurses','pkg-config','poppler','python','sqlite','texinfo','zlib','gcc_'+compiler,'gxx_'+compiler]
 work,packages=s.resolve(root,'emacs-build',{n:'*' for n in names})
 for f in ['pixi.toml','pixi.lock']:shutil.copy2(work/f,app/f)
 s.run([root/'bin/pixi','install','--locked','--manifest-path',app/'pixi.toml']);s.activation(root,app)
 flags+=['--without-native-compilation','--without-xpm','--without-selinux','--without-libsystemd','--without-gpm','--without-mailutils']
 prefix=app/'.pixi/envs/default'
 environment='. '+shlex.quote(str(app/'activate.sh'))+'\n'
 environment+='export CFLAGS="-O2 -pipe" CXXFLAGS="-O2 -pipe"\n'
 environment+='export CPPFLAGS='+shlex.quote('-I'+str(prefix/'include'))+'\n'
 environment+='export LDFLAGS='+shlex.quote('-L'+str(prefix/'lib')+' -Wl,-rpath,'+str(prefix/'lib')+' -Wl,-rpath-link,'+str(prefix/'lib'))+'\n'
 environment+='export PKG_CONFIG_PATH='+shlex.quote(str(prefix/'lib/pkgconfig')+':'+str(prefix/'share/pkgconfig'))+'\n'
else:
 environment='export PATH=/usr/bin:/bin:/usr/sbin:/sbin\n'
 flags+=['--with-native-compilation=aot']
 (app/'activate.sh').write_text('# System library build; no environment activation required.\n')
script=build/'build.sh'
script.write_text('#!/bin/bash\nset -euo pipefail\n'+environment+'cd '+shlex.quote(str(build))+'\n'+shlex.join([str(source/'configure'),*flags])+'\nmake -j'+str(a.jobs)+'\nmake install\n')
s.run(['bash',script])
for cmd in ['emacs','emacsclient','etags','ebrowse']:
 s.wrapper(app,cmd,app/'bin'/cmd)
s.run([app/'launch/emacs','--batch','-Q','--eval','(princ (format "%s %s\\n" emacs-version system-configuration-features))'])
s.receipt(app,dict(name='emacs',version=version,backend='source',source_url='https://ftp.gnu.org/gnu/emacs/'+archive.name,source_sha256=hashlib.sha256(archive.read_bytes()).hexdigest() if not a.source else None, source_commit=s.output(['git','-C',source,'rev-parse','HEAD']).strip() if a.source else None,dependencies=a.deps,configure=flags))
s.atomic_link(app,root/'apps/emacs/current',root)
# Native launcher is separate from the client-based interactive front end.
for command,target in [('emacs-real','emacs'),('emacs-x11','emacs'),('emacsclient','emacsclient'),('etags','etags'),('ebrowse','ebrowse')]:
 s.atomic_link(root/'apps/emacs/current/launch'/target,root/'bin'/command,root)
if a.deps=='system' or not (root/'bin/emacs').exists():
 s.atomic_link(root/'apps/emacs/current/launch/emacs',root/'bin/emacs',root)
print('Installed; running daemon has not been restarted:',app)
