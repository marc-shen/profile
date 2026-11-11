"""Create a real, minimal standalone component without editing framework code."""
import json
from pathlib import Path
import shutil
from .registry import discover, NAME, RESERVED
from .platforms import SUPPORTED


def component_action(action, args, repo, root):
    if action in ('list', 'check'):
        for name, spec in discover(repo, root).items():
            print(name + ': ' + str(spec['_directory']))
        return 0
    if action != 'create' or not args or len(args) > 2 or (len(args) == 2 and args[1] != '--shared'):
        raise RuntimeError('Usage: workbench components create NAME [--shared] (default: local extension)')
    name = args[0]
    if not NAME.fullmatch(name) or name in RESERVED:
        raise RuntimeError('Use a lowercase component name with optional digits/hyphens')
    if name in discover(repo, root):
        raise RuntimeError('Component already exists: ' + name)
    path = (repo / 'components' if '--shared' in args else root / 'extensions') / name
    if path.exists(): raise RuntimeError('Directory already exists: ' + str(path))
    path.mkdir(parents=True)
    template = repo / 'examples/components/example'
    for filename in ('run.py', 'README.md'):
        shutil.copy2(template / filename, path / filename)
    spec = json.loads((template / 'component.json').read_text())
    spec['name'] = name
    (path / 'component.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n')
    print('Created:', path)
    print('Edit component.json and run.py. Immediately available in help and Tab completion.')
    return 0
