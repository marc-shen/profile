"""Declarative component discovery. Listing and completion never import component code."""
from .data import read, CATEGORIES
from pathlib import Path
import re

RESERVED = {'list', 'help'}
NAME = re.compile(r'[a-z][a-z0-9-]*\Z')


def discover(repo, root):
    components = {}
    for directory, filename in ((repo / 'components', 'component.toml'), (repo / 'commands', 'command.toml'), (root / 'extensions', 'component.toml')):
        if not directory.exists():
            continue
        for path in sorted(directory.glob('*/' + filename)):
            spec = read(path)
            name = spec.get('name', '')
            if spec.get('schema') != 1 or not NAME.fullmatch(name) or name != path.parent.name or name in RESERVED:
                raise RuntimeError('Invalid component identity/schema: ' + str(path))
            if name in components:
                raise RuntimeError('Duplicate component ' + name + ': ' + str(path))
            if spec.get('kind') != 'command' and spec.get('category') not in CATEGORIES:
                raise RuntimeError('Unknown or missing category: ' + str(path))
            if not isinstance(spec.get('tags', []), list) or any(not isinstance(t, str) or not NAME.fullmatch(t) for t in spec.get('tags', [])):
                raise RuntimeError('Invalid component tags: ' + str(path))
            actions = spec.get('actions', {})
            if not isinstance(actions, dict) or not actions or any(not NAME.fullmatch(a) for a in actions):
                raise RuntimeError('Invalid actions: ' + str(path))
            for action, info in actions.items():
                if not isinstance(info, dict) or not isinstance(info.get('description'), str):
                    raise RuntimeError('Action requires a description: ' + str(path) + ' ' + action)
            for info in [spec, *actions.values()]:
                if 'arguments' in info and not isinstance(info['arguments'], str):
                    raise RuntimeError('arguments must be a usage string: ' + str(path))
                options = info.get('options', {})
                if not isinstance(options, dict) or any(not isinstance(k, str) or not isinstance(v, str)
                                                        for k, v in options.items()):
                    raise RuntimeError('options must map option syntax to descriptions: ' + str(path))
            entry = spec.get('entrypoint')
            if not isinstance(entry, list) or not entry or any(not isinstance(x, str) for x in entry):
                raise RuntimeError('entrypoint must be an argv array: ' + str(path))
            if not isinstance(spec.get('platforms'), list) or not spec['platforms']:
                raise RuntimeError('platforms required: ' + str(path))
            spec['_directory'] = path.parent
            components[name] = spec
    for name, spec in components.items():
        for dependency in spec.get('requires', []):
            if dependency not in components:
                raise RuntimeError(name + ': unknown dependency ' + dependency)
    # Validate cycles even when only displaying help.
    order(components, list(components))
    return components


def order(components, names):
    result, visiting = [], set()
    def visit(name):
        if name in visiting:
            raise RuntimeError('Dependency cycle at ' + name)
        if name in result:
            return
        visiting.add(name)
        for dependency in components[name].get('requires', []):
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
        return sorted(path.stem for path in (repo / value['directory']).glob('*.toml'))
    path = repo / value['catalog']
    if value.get('format') == 'sources':
        return [line.split()[0] for line in path.read_text().splitlines() if line.strip() and not line.startswith('#')]
    return list(read(path))


def supported(spec, action, platform):
    return platform in spec['actions'][action].get('platforms', spec['platforms'])
