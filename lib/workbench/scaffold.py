"""Create a real, minimal standalone module without editing framework code."""
import json
from pathlib import Path
import shutil
from .registry import discover, NAME
from .platforms import SUPPORTED


def module_action(action, args, repo, root):
    if action in ('list', 'check'):
        for name, spec in discover(repo, root).items():
            print(name + ': ' + str(spec['_directory']))
        return 0
    if action != 'create' or not args or len(args) > 2 or (len(args) == 2 and args[1] != '--shared'):
        raise RuntimeError('Usage: workbench modules create NAME [--shared] (default: local extension)')
    name = args[0]
    if not NAME.fullmatch(name) or name in ('list', 'help'):
        raise RuntimeError('Use a lowercase module name with optional digits/hyphens')
    if name in discover(repo, root):
        raise RuntimeError('Module already exists: ' + name)
    path = (repo / 'modules' if '--shared' in args else root / 'extensions') / name
    if path.exists(): raise RuntimeError('Directory already exists: ' + str(path))
    path.mkdir(parents=True)
    template = repo / 'examples/modules/example'
    for filename in ('run.py', 'README.md'):
        shutil.copy2(template / filename, path / filename)
    spec = json.loads((template / 'module.json').read_text())
    spec['name'] = name
    (path / 'module.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n')
    print('Created:', path)
    print('Edit module.json and run.py. Immediately available in help and Tab completion.')
    return 0
