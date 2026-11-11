"""Declarative module discovery. Listing and completion never import module code."""
import json
from pathlib import Path
import re

NAME = re.compile(r'[a-z][a-z0-9-]*\Z')


def read(path):
    return json.loads(path.read_text())


def discover(repo, root):
    modules = {}
    for directory in (repo / 'modules', root / 'extensions'):
        if not directory.exists():
            continue
        for path in sorted(directory.glob('*/module.json')):
            spec = read(path)
            name = spec.get('name', '')
            if spec.get('schema') != 1 or not NAME.fullmatch(name) or name != path.parent.name or name in ('list', 'help'):
                raise RuntimeError('Invalid module identity/schema: ' + str(path))
            if name in modules:
                raise RuntimeError('Duplicate module ' + name + ': ' + str(path))
            actions = spec.get('actions', {})
            if not isinstance(actions, dict) or not actions or any(not NAME.fullmatch(a) for a in actions):
                raise RuntimeError('Invalid actions: ' + str(path))
            for action, info in actions.items():
                if not isinstance(info, dict) or not isinstance(info.get('description'), str):
                    raise RuntimeError('Action requires a description: ' + str(path) + ' ' + action)
            entry = spec.get('entrypoint')
            if not isinstance(entry, list) or not entry or any(not isinstance(x, str) for x in entry):
                raise RuntimeError('entrypoint must be an argv array: ' + str(path))
            if not isinstance(spec.get('platforms'), list) or not spec['platforms']:
                raise RuntimeError('platforms required: ' + str(path))
            spec['_directory'] = path.parent
            modules[name] = spec
    for name, spec in modules.items():
        for dependency in spec.get('requires', []):
            if dependency not in modules:
                raise RuntimeError(name + ': unknown dependency ' + dependency)
    # Validate cycles even when only displaying help.
    order(modules, list(modules))
    return modules


def order(modules, names):
    result, visiting = [], set()
    def visit(name):
        if name in visiting:
            raise RuntimeError('Dependency cycle at ' + name)
        if name in result:
            return
        visiting.add(name)
        for dependency in modules[name].get('requires', []):
            visit(dependency)
        visiting.remove(name)
        result.append(name)
    for name in names:
        visit(name)
    return result


def targets(spec, action, repo):
    value = spec['actions'][action].get('targets', spec.get('targets', []))
    if isinstance(value, list):
        return value
    if 'directory' in value:
        return sorted(path.stem for path in (repo / value['directory']).glob('*.json'))
    path = repo / value['catalog']
    if value.get('format') == 'sources':
        return [line.split()[0] for line in path.read_text().splitlines() if line.strip() and not line.startswith('#')]
    return list(read(path))


def supported(spec, action, platform):
    return platform in spec['actions'][action].get('platforms', spec['platforms'])
