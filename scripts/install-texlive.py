#!/usr/bin/env python3
"""Optional upstream TeX Live for Linux; never writes to system directories."""
import argparse, hashlib, os, platform, re, shlex, subprocess
from pathlib import Path
from software import atomic_link, fetch, receipt, run

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home()/'Software'))))
p.add_argument('--repository', default='https://mirror.ctan.org/systems/texlive/tlnet')
a = p.parse_args()
if platform.system() != 'Linux':
    p.error('This optional installer currently supports Linux only.')
root = a.prefix.expanduser().resolve()
archive = root/'downloads/texlive/install-tl-unx.tar.gz'
# This URL changes daily; resuming yesterday's archive would corrupt it.
fresh_archive = archive.with_suffix('.fresh')
fresh_archive.unlink(missing_ok=True)
fetch(a.repository.rstrip('/')+'/install-tl-unx.tar.gz', fresh_archive)
os.replace(fresh_archive, archive)
work = root/'build/texlive-installer'
work.mkdir(parents=True, exist_ok=True)
run(['tar', '-xzf', archive, '-C', work, '--strip-components=1'])
year = re.search(r'version (\d{4})', (work/'release-texlive.txt').read_text()).group(1)
app = root/'apps/texlive'/year
arch = {'x86_64':'x86_64-linux', 'aarch64':'aarch64-linux'}[platform.machine()]
binpath = app/'bin'/arch
profile = work/'software.profile'
profile.write_text('\n'.join([
    'selected_scheme scheme-medium', 'binary_'+arch+' 1',
    'TEXDIR '+str(app), 'TEXMFLOCAL '+str(root/'share/texmf-local'),
    'TEXMFSYSCONFIG '+str(app/'texmf-config'), 'TEXMFSYSVAR '+str(app/'texmf-var'),
    'TEXMFHOME ~/Software/share/texmf',
    'TEXMFCONFIG ~/Software/config/texlive/'+year,
    'TEXMFVAR ~/Software/cache/texlive/'+year,
    'instopt_adjustpath 0', 'instopt_letter 0',
    'tlpdbopt_install_docfiles 0', 'tlpdbopt_install_srcfiles 0', ''
]))
if not (app/'tlpkg/texlive.tlpdb').exists():
    run(['perl', work/'install-tl', '--profile', profile, '--repository', a.repository], cwd=work)
packages = ['collection-langchinese', 'collection-latexextra', 'collection-bibtexextra', 'latexmk', 'biber']
env = dict(os.environ, PATH=str(binpath)+':'+os.environ['PATH'])
run([binpath/'tlmgr', '--repository', a.repository, 'install', 'scheme-medium', *packages], env=env)
for command in ['xelatex', 'pdflatex', 'lualatex', 'latexmk', 'biber']:
    run([binpath/command, '--version'], stdout=subprocess.DEVNULL, env=env)
sample = work/'verify.tex'
sample.write_text('\\documentclass[fontset=fandol]{ctexart}\n\\begin{document}中文排版验证 $E=mc^2$\\end{document}\n')
run([binpath/'xelatex', '-interaction=nonstopmode', '-halt-on-error', sample.name], cwd=work, env=env, stdout=subprocess.DEVNULL)
receipt(app, dict(name='texlive', version=year, backend='upstream', repository=a.repository,
    scheme='medium', extra_packages=packages, docs=False, sources=False,
    installer_sha256=hashlib.sha256(archive.read_bytes()).hexdigest()))
atomic_link(app, root/'apps/texlive/current', root)
# Keep the complete native bin directory available to child commands (latexmk, tlmgr).
commands = 'tex latex pdftex pdflatex xetex xelatex luatex lualatex latexmk bibtex biber makeindex makeglossaries kpsewhich tlmgr texdoc fmtutil updmap dvipdfmx'.split()
launch = app/'launch'
launch.mkdir(exist_ok=True)
for command in commands:
    if not (binpath/command).exists():
        continue
    entry = launch/command
    entry.write_text('#!/bin/sh\nexport PATH='+shlex.quote(str(binpath))+':"$PATH"\nexec '+shlex.quote(str(binpath/command))+' "$@"\n')
    entry.chmod(0o755)
    atomic_link(root/'apps/texlive/current/launch'/command, root/'bin'/command, root)
module = root/'share/modulefiles/texlive'/year
module.parent.mkdir(parents=True, exist_ok=True)
module.write_text('#%Module1.0\nconflict texlive\nprepend-path PATH {'+str(binpath)+'}\n')
atomic_link(module, module.parent/'current', root)
print('Installed:', app, '\nUpdate within this release: tlmgr update --self --all')
