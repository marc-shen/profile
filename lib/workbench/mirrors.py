"""CERNET mirror dispatch with native signature checks and reversible changes."""
import datetime
import json
from pathlib import Path
import re
import subprocess as sp
import tempfile
import urllib.parse
import urllib.request
from .data import read
from .ui import Console

DEFAULTS = {'fedora': 'dnf', 'ubuntu': 'apt', 'steamdeck': 'flatpak'}
FEDORA_PATHS = {
    'fedora': 'releases/$releasever/Everything/$basearch/os/',
    'fedora-debuginfo': 'releases/$releasever/Everything/$basearch/debug/tree/',
    'fedora-source': 'releases/$releasever/Everything/source/tree/',
    'updates': 'updates/$releasever/Everything/$basearch/',
    'updates-debuginfo': 'updates/$releasever/Everything/$basearch/debug/',
    'updates-source': 'updates/$releasever/Everything/source/tree/',
}


def catalog(repo):
    return read(repo / 'catalog/mirrors.toml')


class HTTPSRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != 'https':
            raise RuntimeError('Mirror redirected to a non-HTTPS URL')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def probe(url, kind):
    """Read bounded metadata, not a mirror home page or a cached HEAD result."""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), HTTPSRedirectHandler())
    request = urllib.request.Request(url, headers={'User-Agent': 'Workbench-mirrors/1'})
    with opener.open(request, timeout=12) as response:
        data = response.read(262144)
        if response.status != 200 or urllib.parse.urlsplit(response.url).scheme != 'https':
            raise RuntimeError('Invalid HTTPS metadata response')
        origin = urllib.parse.urlsplit(url).hostname
        destination = urllib.parse.urlsplit(response.url).hostname
        # CERNET is a dispatcher: member mirror redirects are its normal API.
        # Keep the original CERNET URL in configuration, never pin this result.
        dispatcher = origin == 'mirrors.cernet.edu.cn' or origin.endswith('.mirrors.cernet.edu.cn')
        same_site = dispatcher or origin == destination or any(
            origin.endswith('.' + domain) and destination.endswith('.' + domain)
            for domain in ('tsinghua.edu.cn', 'ustc.edu.cn', 'sjtu.edu.cn'))
        if not same_site:
            raise RuntimeError('Mirror redirects metadata outside its site; skipped')
    if kind == 'apt' and not data.startswith(b'-----BEGIN PGP SIGNED MESSAGE-----'):
        raise RuntimeError('Missing signed InRelease metadata')
    if kind == 'dnf' and b'<repomd' not in data:
        raise RuntimeError('Missing repomd metadata')
    if kind == 'flatpak' and not (b'[core]' in data and b'repo_version=' in data):
        raise RuntimeError('Missing OSTree repository configuration')
    if kind == 'summary' and (not data or b'<html' in data[:512].lower() or b'<!doctype' in data[:512].lower()):
        raise RuntimeError('Invalid OSTree summary')
    return response.url


def candidates(settings, target):
    for name in settings['priority']:
        site = settings['sites'][name]
        if target == 'flatpak' and 'flatpak' not in site:
            Console().status('SKIP', site['name'] + ': 未提供 Flathub', 'warn')
            continue
        yield name, site


def apt_path(url, settings):
    parsed = urllib.parse.urlsplit(url)
    host, path = parsed.hostname or '', parsed.path.rstrip('/')
    known = {urllib.parse.urlsplit(site['base']).hostname for site in settings['sites'].values()}
    known_mirror = host in known or any(host == domain or host.endswith('.' + domain)
                                      for domain in settings['proxy']['direct_domains'])
    known_mirror = known_mirror or any(re.fullmatch(pattern, host) for pattern in settings['proxy'].get('direct_regex', []))
    official = host in ('archive.ubuntu.com', 'security.ubuntu.com', 'ports.ubuntu.com') or host.endswith('.archive.ubuntu.com')
    return path.lstrip('/') if (official or known_mirror) and path in ('/ubuntu', '/ubuntu-ports') else None


def apt_transform(content, site, settings, deb822=False):
    """Keep suites, architectures, Signed-By, components and third-party sources."""
    probes = set()
    if deb822:
        for block in re.split(r'\n\s*\n', content):
            fields = {}
            key = None
            for line in block.splitlines():
                if line.lstrip().startswith('#'): continue
                if line[:1].isspace() and key:
                    fields[key] += ' ' + line.strip()
                elif ':' in line:
                    key, value = line.split(':', 1); key = key.lower(); fields[key] = value.strip()
            if fields.get('enabled', '').lower() == 'no': continue
            for url in fields.get('uris', '').split():
                path = apt_path(url, settings)
                if path:
                    probes.update(site['base'] + '/' + path + '/dists/' + suite + '/InRelease'
                                  for suite in fields.get('suites', '').split())
    else:
        for line in content.splitlines():
            match = re.match(r'^\s*deb(?:-src)?\s+(?:\[[^]]*\]\s+)?(https?://\S+)\s+(\S+)', line)
            if match and (path := apt_path(match[1], settings)):
                probes.add(site['base'] + '/' + path + '/dists/' + match[2] + '/InRelease')
    def replace(match):
        url = match[0]
        path = apt_path(url, settings)
        return site['base'] + '/' + path + '/' if path else url
    # Only URL tokens change; PPA/vendor URLs and keyring settings are preserved.
    return re.sub(r'https?://[^\s\]<>"\']+', replace, content), sorted(probes)


def dnf_transform(content, site, release, arch):
    blocks = re.split(r'(?m)(?=^\[)', content)
    result, probes = [], []
    for block in blocks:
        heading = re.match(r'\[([^]]+)\]', block)
        name = heading[1] if heading else ''
        if name not in FEDORA_PATHS:
            result.append(block); continue
        url = site['fedora'] + '/' + FEDORA_PATHS[name]
        lines = block.splitlines(keepends=True)
        # Preserve every non-location setting, including enabled and gpgcheck.
        kept = [line for line in lines[1:] if not re.match(r'^\s*#?\s*(?:baseurl|metalink|mirrorlist)\s*=', line)]
        result.append(lines[0].rstrip('\n') + '\nbaseurl=' + url + '\n' + ''.join(kept))
        disabled = re.search(r'(?m)^\s*enabled\s*=\s*0\s*$', block)
        if not disabled:
            probes.append(url.replace('$releasever', release).replace('$basearch', arch) + 'repodata/repomd.xml')
    return ''.join(result), probes


def native_changes(target, site, settings, etc=Path('/etc'), release=None, arch=None):
    before, after, probes = {}, {}, []
    if target == 'apt':
        files = [etc / 'apt/sources.list', *sorted((etc / 'apt/sources.list.d').glob('*.list')),
                 *sorted((etc / 'apt/sources.list.d').glob('*.sources'))]
    else:
        files = [etc / 'yum.repos.d/fedora.repo', etc / 'yum.repos.d/fedora-updates.repo']
    for path in files:
        if not path.is_file(): continue
        if path.is_symlink(): raise RuntimeError('Refusing to replace a symlinked repository file: ' + str(path))
        old = path.read_text()
        new, urls = (apt_transform(old, site, settings, path.suffix == '.sources') if target == 'apt'
                     else dnf_transform(old, site, release, arch))
        if new != old or urls:
            before[str(path)], after[str(path)] = old, new
            probes.extend(urls)
    if not probes: raise RuntimeError('No supported enabled distribution repositories found')
    return before, after, sorted(set(probes))


def call(argv, **kwargs):
    return sp.run(list(map(str, argv)), check=True, timeout=240, **kwargs)


def write_native(path, content):
    path = Path(path)
    if path.is_symlink(): raise RuntimeError('Refusing symlink: ' + str(path))
    mode = oct(path.stat().st_mode & 0o777)[2:]
    with tempfile.NamedTemporaryFile(mode='w') as stage:
        stage.write(content); stage.flush()
        temporary = str(path) + '.workbench-new'
        call(['sudo', 'install', '-m', mode, stage.name, temporary])
        call(['sudo', 'mv', '--', temporary, path])


def flatpak_remotes():
    result = {}
    for scope in ('user', 'system'):
        listing = call(['flatpak', 'remotes', '--' + scope, '--columns=name,url'], capture_output=True, text=True).stdout
        for line in listing.splitlines():
            fields = line.split('\t')
            if len(fields) >= 2 and fields[0] == 'flathub': result[scope] = fields[1]
    return result


def write_flatpak(scope, url):
    # Flatpak's normal polkit authorization handles system-wide remotes. It writes
    # /var/lib/flatpak, which remains writable on SteamOS with root read-only.
    call(['flatpak', 'remote-modify', '--' + scope, 'flathub', '--url=' + url])


def validate(target, entries):
    if target == 'flatpak':
        for scope in entries:
            # Fetch signed repository metadata without installing/updating applications.
            call(['flatpak', 'remote-ls', '--' + scope, 'flathub', '--columns=ref'], stdout=sp.DEVNULL)
    elif target == 'dnf':
        call(['sudo', 'dnf', '--disablerepo=*', '--enablerepo=fedora', '--enablerepo=updates',
              '--setopt=skip_if_unavailable=False', 'makecache', '--refresh'])
    else:
        call(['sudo', 'apt-get', '-o', 'APT::Update::Error-Mode=any', 'update'])


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n'); temp.chmod(0o600); temp.replace(path)


def transaction(root, target, before, after, site, writer, validator, reader=None):
    folder = root / 'data/mirrors'
    state_path, pending = folder / (target + '.json'), folder / (target + '.pending.json')
    if pending.exists(): raise RuntimeError('Interrupted mirror operation; run workbench mirrors restore ' + target)
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if state and state['applied'] != before:
        raise RuntimeError('Repository configuration changed outside Workbench; inspect before applying again')
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = root / 'backups/mirrors' / (stamp + '-' + target + '.json')
    save(backup, before)
    save(pending, {'before': before, 'after': after, 'backup': str(backup)})
    changed = []
    try:
        for key, value in after.items():
            if before[key] != value:
                changed.append(key); writer(key, value)
        validator(target, after)
        save(state_path, {'site': site, 'original': state.get('original', before), 'applied': after, 'backup': str(backup)})
    except BaseException:
        # A denied authorization may leave every value untouched. Do not ask
        # for authorization again merely to write the same original URL.
        actual = None
        if reader:
            try: actual = reader()
            except (OSError, sp.SubprocessError): pass
        for key in reversed(changed):
            if actual is None or actual.get(key) != before[key]: writer(key, before[key])
        pending.unlink()
        raise
    pending.unlink()


def current_values(target, entries):
    if target == 'flatpak': return flatpak_remotes()
    return {path: Path(path).read_text() for path in entries}


def restore(root, target):
    folder = root / 'data/mirrors'
    pending, state_path = folder / (target + '.pending.json'), folder / (target + '.json')
    source = pending if pending.exists() else state_path
    if not source.exists(): raise RuntimeError('No saved mirror configuration for ' + target)
    state = json.loads(source.read_text())
    desired = state['before'] if source == pending else state['original']
    current = current_values(target, desired)
    if source == state_path and current != state['applied']:
        raise RuntimeError('Repository configuration changed outside Workbench; refusing to overwrite it')
    writer = write_flatpak if target == 'flatpak' else write_native
    done = []
    try:
        for key, value in desired.items():
            if current[key] != value:
                done.append(key); writer(key, value)
    except BaseException:
        for key in reversed(done): writer(key, current[key])
        raise
    source.unlink()
    Console().status('OK', target + ': 已恢复换源前的配置', 'ok')


def mirror_action(action, args, repo, root, platform):
    if len(args) > 1: raise RuntimeError('mirrors accepts one target: auto|dnf|flatpak|apt')
    target = args[0] if args else 'auto'
    if target == 'auto': target = DEFAULTS.get(platform)
    settings = catalog(repo)
    console = Console()
    if action == 'list':
        console.table([(name, settings['sites'][name]['name'] + '  ' + settings['sites'][name]['base']) for name in settings['priority']])
        console.print('当前平台：' + platform + '；默认对象：' + (DEFAULTS.get(platform) or '无'))
        if target:
            path = root / 'data/mirrors' / (target + '.json')
            console.print('已配置：' + (json.loads(path.read_text())['site'] if path.exists() else '尚未由 Workbench 换源'))
            if target == 'flatpak' and platform == 'steamdeck': console.table(list(flatpak_remotes().items()))
        return 0
    if target != DEFAULTS.get(platform) or target is None:
        raise RuntimeError('Use this platform’s native target: ' + str(DEFAULTS.get(platform)))
    if action == 'restore':
        if target != 'flatpak': call(['sudo', '-v'])
        restore(root, target); return 0
    if action == 'check':
        if (root / 'data/mirrors' / (target + '.pending.json')).exists():
            console.status('PENDING', '换源中断；先运行 workbench mirrors restore ' + target, 'warn'); return 2
        path = root / 'data/mirrors' / (target + '.json')
        if not path.exists(): console.status('MISSING', target + ' 尚未换源', 'warn'); return 2
        state = json.loads(path.read_text())
        if current_values(target, state['applied']) != state['applied']:
            console.status('CHANGED', target + ' 配置与记录不一致', 'warn'); return 2
        site = settings['sites'].get(state['site'])
        if not site or state['site'] not in settings['priority']:
            console.status('PENDING', '镜像策略已更新；运行 workbench mirrors apply ' + target, 'warn'); return 2
        if target == 'flatpak':
            probe(site['flatpak'] + '/config', 'flatpak'); probe(site['flatpak'] + '/summary.idx', 'summary')
        else:
            release, arch = fedora_identity() if target == 'dnf' else (None, None)
            _, _, urls = native_changes(target, site, settings, release=release, arch=arch)
            for url in urls: probe(url, target)
        console.status('OK', target + ': ' + site['name'], 'ok'); return 0
    if action not in ('apply', 'install', 'update'): raise RuntimeError('Unknown mirror action')
    if target != 'flatpak': call(['sudo', '-v'])
    pending = root / 'data/mirrors' / (target + '.pending.json')
    if pending.exists(): raise RuntimeError('Interrupted operation; run workbench mirrors restore ' + target)
    release, arch = fedora_identity() if target == 'dnf' else (None, None)
    for name, site in candidates(settings, target):
        console.status('TRY', site['name'] + ' / ' + target, 'key')
        try:
            if target == 'flatpak':
                before = flatpak_remotes()
                if not before: raise RuntimeError('Add a trusted Flathub remote first: flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo')
                after = {scope: site['flatpak'] for scope in before}
                probe(site['flatpak'] + '/config', 'flatpak'); probe(site['flatpak'] + '/summary.idx', 'summary')
            else:
                before, after, urls = native_changes(target, site, settings, release=release, arch=arch)
                for url in urls: probe(url, target)
        except (RuntimeError, OSError, sp.SubprocessError) as error:
            console.status('SKIP', site['name'] + ': ' + str(error), 'warn'); continue
        try:
            transaction(root, target, before, after, name, write_flatpak if target == 'flatpak' else write_native,
                        validate, lambda: current_values(target, before))
        except sp.SubprocessError as error:
            if pending.exists(): raise RuntimeError('Rollback incomplete; run workbench mirrors restore ' + target) from error
            console.status('SKIP', site['name'] + ': 验证失败，已恢复原配置', 'warn'); continue
        console.status('OK', target + ' → ' + site['name'], 'ok'); return 0
    raise RuntimeError('No usable mirror; original configuration retained')


def fedora_identity():
    release = sp.check_output(['rpm', '-E', '%fedora'], text=True).strip()
    arch = sp.check_output(['rpm', '-E', '%_arch'], text=True).strip()
    if not release.isdigit() or not re.fullmatch(r'[a-zA-Z0-9_]+', arch):
        raise RuntimeError('Cannot determine Fedora release/architecture')
    return release, arch
