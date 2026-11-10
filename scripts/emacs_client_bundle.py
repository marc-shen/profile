"""Build the unified app from its replaceable Contents/Runtime/Emacs.app.

The input app is never modified. A copy of the small launcher overlay travels
with the installed app so later runtime upgrades do not require deployment.
"""
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

INPUT = Path('Contents/Runtime/Emacs.app')
OVERLAY = Path('Contents/Resources/ProfileLauncher')
MARKER = Path('Contents/Resources/profile-runtime.json')
FORMAT = 2


def runtime_signature(runtime):
    digest = hashlib.sha256()
    for relative in ('Contents/Info.plist', 'Contents/_CodeSignature/CodeResources'):
        digest.update((runtime / relative).read_bytes())
    return digest.hexdigest()


def runtime_marker(runtime, overlay_digest):
    return {'format': FORMAT, 'overlay': overlay_digest,
            'runtime': runtime_signature(runtime),
            'input': input_link(runtime)}


def input_link(runtime):
    """Return the stable external target, or None for a dropped full app."""
    runtime = Path(runtime)
    if runtime.name != 'Emacs.app' or runtime.parent.name != 'Runtime':
        # Keep /Applications/Emacs.app stable even if Homebrew makes it a link
        # to a versioned Caskroom directory.
        return str(runtime.absolute())
    if runtime.is_symlink():
        target = Path(os.readlink(runtime))
        if not target.is_absolute():
            target = runtime.parent / target
        return os.path.abspath(target)
    return None


def selected_runtime(bundle):
    candidate = bundle / INPUT
    # A broken user-supplied link must fail visibly, never select another version.
    if candidate.exists() or candidate.is_symlink() or (bundle / OVERLAY).is_dir():
        return candidate
    return Path('/Applications/Emacs.app')


def build_bundle(source, runtime, destination, overlay_digest):
    runtime = Path(runtime)
    if destination.exists():
        raise FileExistsError(destination)
    if not (runtime / 'Contents/MacOS/Emacs').is_file():
        raise ValueError(f'Not a native Emacs.app: {runtime}')
    if runtime.resolve() == source.resolve() or runtime.resolve() == destination.resolve():
        raise ValueError('Runtime must be an upstream Emacs.app, not Emacs Client.app')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(runtime)], check=True)
    marker = runtime_marker(runtime, overlay_digest)
    # ditto preserves SDK resource forks and detached signatures.
    subprocess.run(['/usr/bin/ditto', str(runtime), str(destination)], check=True)
    upstream_info = plistlib.loads((destination / 'Contents/Info.plist').read_bytes())
    overlay_info = plistlib.loads((source / 'Contents/Info.plist').read_bytes())
    if upstream_info.get('CFBundleIdentifier') == overlay_info.get('CFBundleIdentifier'):
        raise ValueError('Runtime must be an upstream Emacs.app, not Emacs Client.app')
    upstream_info.update(overlay_info)
    for directory in ('MacOS', 'Resources'):
        shutil.copytree(source / 'Contents' / directory,
                        destination / 'Contents' / directory,
                        dirs_exist_ok=True, symlinks=True)
    (destination / 'Contents/Info.plist').write_bytes(plistlib.dumps(upstream_info))
    # Preserve the user's choice: a dropped app remains self-contained; a link
    # remains a link. Resolve links before moving the enclosing app bundle.
    slot = destination / INPUT
    slot.parent.mkdir(parents=True)
    if marker['input'] is not None:
        slot.symlink_to(marker['input'])
    else:
        subprocess.run(['/usr/bin/ditto', str(runtime), str(slot)], check=True)
    shutil.copytree(source, destination / OVERLAY, symlinks=True)
    # Keep the auto-updater in the signed overlay, without requiring the checkout.
    for binary in (destination / 'Contents/MacOS').iterdir():
        if binary.is_file() and binary.name.startswith('Emacs') and binary.suffix != '.pdmp':
            subprocess.run(['codesign', '--force', '--sign', '-', str(binary)], check=True)
    (destination / MARKER).write_text(json.dumps(marker))
    subprocess.run(['codesign', '--force', '--sign', '-', str(destination)], check=True)
    # External runtime links are intentional; codesign --strict rejects them.
    # Verify the ordinary deep seal here; the upstream input was verified strictly.
    subprocess.run(['codesign', '--verify', '--deep', str(destination)], check=True)
    if runtime_marker(runtime, overlay_digest) != marker:
        raise RuntimeError('Emacs.app changed during preparation; retry after copying finishes')


def ensure_runtime(bundle, backup_root=None):
    """Called before exec by the daemon wrapper, never kills a running daemon."""
    bundle = Path(bundle).absolute()
    # Lock outside the replaceable bundle so simultaneous requests share a lock.
    with (bundle.parent / '.emacs-client-runtime.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        runtime = bundle / INPUT
        marker = json.loads((bundle / MARKER).read_text())
        if marker == runtime_marker(runtime, marker['overlay']):
            return False
        print(f'Preparing Emacs runtime from {runtime}', file=sys.stderr)
        backup_root = backup_root or Path.home() / 'Software/backups'
        backup = Path(backup_root) / ('emacs-runtime-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        with tempfile.TemporaryDirectory(prefix='.emacs-client-', dir=bundle.parent) as tmp:
            prepared = Path(tmp) / bundle.name
            build_bundle(bundle / OVERLAY, runtime, prepared, marker['overlay'])
            backup.mkdir(parents=True)
            old = backup / bundle.name
            bundle.rename(old)
            try:
                prepared.rename(bundle)
            except BaseException:
                old.rename(bundle)
                raise
        print(f'Emacs runtime updated; previous bundle: {old}', file=sys.stderr)
        return True


if __name__ == '__main__':
    try:
        ensure_runtime(Path(sys.argv[1]))
    except Exception as error:
        print(f'Unable to prepare Emacs runtime: {error}', file=sys.stderr)
        sys.exit(1)
