#!/usr/bin/env python3
"""Generate modules only for installed Homebrew compilers; keep personal research modules."""
import datetime,os,re,shutil,subprocess as sp
from pathlib import Path
root=Path(os.environ.get('SOFTWARE_HOME',str(Path.home()/'Software')))
mods=root/'share/modulefiles';backup=root/'backups'/('mac-modules-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
def save(p):
 dst=backup/p.relative_to(mods);dst.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(p),dst)
# Remove stale modules and .bak copies from the active module search path.
for p in list(mods.rglob('*')):
 if not p.is_file():continue
 text=p.read_text(errors='replace')
 m=re.search(r'^set\s+basedir\s+["{]?([^\s"}]+)',text,re.M)
 if p.suffix=='.bak' or (m and m.group(1).startswith('/') and not Path(m.group(1)).exists()):save(p)
brew=shutil.which('brew') or '/opt/homebrew/bin/brew'
for formula in ['gcc','gcc@14']:
 result=sp.run([brew,'--prefix',formula],capture_output=True,text=True)
 if result.returncode:continue
 prefix=Path(result.stdout.strip())
 for exe in prefix.glob('bin/gcc-[0-9]*'):
  major=exe.name.split('-')[-1]
  if not major.isdigit():continue
  version=sp.check_output([exe,'-dumpfullversion'],text=True).strip()
  p=mods/'gcc'/version;p.parent.mkdir(parents=True,exist_ok=True)
  text='#%Module1.0\nmodule-whatis "Homebrew GCC '+version+'"\nconflict gcc clang llvm intel-compilers\n'
  text+='set root {'+str(prefix.resolve())+'}\nprepend-path PATH $root/bin\nprepend-path MANPATH $root/share/man\n'
  for variable,command in [('CC','gcc'),('CXX','g++'),('FC','gfortran'),('F77','gfortran')]:text+='pushenv '+variable+' $root/bin/'+command+'-'+major+'\n'
  text+='prepend-path CMAKE_PREFIX_PATH $root\n'
  if p.exists() and p.read_text()!=text:save(p)
  p.write_text(text)
  # No duplicate abbreviated module with obsolete flags.
  old=mods/'gcc'/'.'.join(version.split('.')[:2])
  if old.exists() and old!=p:save(old)
# Correct the old gcc/system label: /usr/bin/gcc is Apple Clang.
old=mods/'gcc/system'
if old.exists():save(old)
p=mods/'clang/system';p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('#%Module1.0\nmodule-whatis "Apple Clang (Xcode Command Line Tools)"\nconflict gcc clang llvm intel-compilers\npushenv CC /usr/bin/clang\npushenv CXX /usr/bin/clang++\n')
print('Refreshed compiler modules; originals:',backup)
