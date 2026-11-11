#!/usr/bin/env python3
"""Optional official WezTerm AppImage, extracted without FUSE or system changes."""
import argparse, hashlib, json, os, platform, shlex, subprocess
from pathlib import Path
from software import atomic_link, fetch, receipt, run

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home()/'Software'))))
p.add_argument('--release-json', type=Path, help='Use already downloaded GitHub release metadata')
a = p.parse_args()
if (platform.system(), platform.machine()) != ('Linux', 'x86_64'):
    p.error('This AppImage installer currently supports Linux x86_64 only.')
root = a.prefix.expanduser().resolve()
downloads = root/'downloads/wezterm'
metadata = a.release_json or downloads/'release.json'
if not a.release_json:
    fetch('https://api.github.com/repos/wezterm/wezterm/releases/latest', metadata)
release = json.loads(metadata.read_text())
asset = next(x for x in release['assets'] if x['name'].endswith('.AppImage'))
checksum = next(x for x in release['assets'] if x['name'] == asset['name']+'.sha256')
archive, sums = downloads/asset['name'], downloads/checksum['name']
if not a.release_json or not sums.exists():
    fetch(checksum['browser_download_url'], sums)
expected = sums.read_text().split()[0]
if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    fetch(asset['browser_download_url'], archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise RuntimeError('WezTerm AppImage SHA256 mismatch')
app = root/'apps/wezterm'/release['tag_name']
app.mkdir(parents=True, exist_ok=True)
archive.chmod(0o755)
if not (app/'squashfs-root/AppRun').exists():
    run([archive, '--appimage-extract'], cwd=app, stdout=subprocess.DEVNULL)
# SteamOS updates its Compose tables independently of the older stable AppImage.
# Use the matching host xkbcommon ABI; retain the bundled libraries for rollback.
host_libraries = []
if Path('/etc/os-release').exists() and 'ID=steamos' in Path('/etc/os-release').read_text():
    for name in ['libxkbcommon.so.0', 'libxkbcommon-x11.so.0']:
        host = Path('/usr/lib')/name
        bundled = app/'squashfs-root/usr/lib'/name
        if host.exists() and bundled.exists():
            saved = app/'bundled-libraries'/name
            saved.parent.mkdir(exist_ok=True)
            if not saved.exists():
                bundled.rename(saved)
            elif bundled.is_symlink():
                bundled.unlink()
            else:
                raise RuntimeError('Unexpected existing library: '+str(bundled))
            bundled.symlink_to(host)
            host_libraries.append(str(host))
launch = app/'launch'
launch.mkdir(exist_ok=True)
entry = launch/'wezterm'
entry.write_text('#!/bin/sh\n'
    '# Steam injects both overlay architectures. Do not pass them to the terminal\n'
    '# or its children; preserve unrelated preloads (for example input helpers).\n'
    'case ${LD_PRELOAD-} in\n'
    '  *gameoverlayrenderer.so*)\n'
    '    wezterm_preload=\n'
    '    wezterm_saved_ifs=$IFS\n'
    '    IFS=" :"\n'
    '    set -f\n'
    '    for wezterm_library in $LD_PRELOAD; do\n'
    '      case $wezterm_library in\n'
    '        gameoverlayrenderer.so|*/gameoverlayrenderer.so) ;;\n'
    '        *) wezterm_preload=${wezterm_preload:+$wezterm_preload:}$wezterm_library ;;\n'
    '      esac\n'
    '    done\n'
    '    set +f\n'
    '    IFS=$wezterm_saved_ifs\n'
    '    if [ -n "$wezterm_preload" ]; then\n'
    '      export LD_PRELOAD=$wezterm_preload\n'
    '    else\n'
    '      unset LD_PRELOAD\n'
    '    fi\n'
    '    unset wezterm_preload wezterm_saved_ifs wezterm_library\n'
    '    ;;\n'
    'esac\n'
    '# Load the same base environment used by terminals and Emacs.\n'
    '[ ! -r '+shlex.quote(str(root/'env.sh'))+' ] || . '+shlex.quote(str(root/'env.sh'))+'\n'
    'exec '+shlex.quote(str(app/'squashfs-root/AppRun'))+' "$@"\n')
entry.chmod(0o755)
run([entry, '--version'])
run([entry, 'show-keys'], stdout=subprocess.DEVNULL)
receipt(app, dict(name='wezterm', version=release['tag_name'], backend='upstream-appimage',
    url=asset['browser_download_url'], sha256=expected, extracted=True, host_libraries=host_libraries))
atomic_link(app, root/'apps/wezterm/current', root)
atomic_link(root/'apps/wezterm/current/launch/wezterm', root/'bin/wezterm', root)
desktop = Path.home()/'.local/share/applications/org.wezfurlong.wezterm.desktop'
desktop.parent.mkdir(parents=True, exist_ok=True)
icon = next((app/'squashfs-root').rglob('org.wezfurlong.wezterm.png'), None)
desktop.write_text('[Desktop Entry]\nType=Application\nName=WezTerm\nComment=Terminal with the shared Software environment\n'
    'Exec="'+str(root/'bin/wezterm')+'" start\n'
    'Icon='+str(icon or 'utilities-terminal')+'\nTerminal=false\nCategories=System;TerminalEmulator;\nStartupWMClass=org.wezfurlong.wezterm\n')
print('Installed:', app, '\nDesktop entry:', desktop)
