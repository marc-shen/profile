"""One grammar for built-in and local modules: MODULE ACTION [TARGET ...]."""
import argparse
import json
import os
from pathlib import Path
import sys
from . import __version__
from . import engine, registry
from .platforms import detect, SUPPORTED

REPO = Path(__file__).resolve().parents[2]


def load_profile(repo, name, seen=()):
    if not registry.NAME.fullmatch(name) or name in seen:
        raise RuntimeError('Invalid or cyclic installation profile: ' + name)
    path = repo / 'profiles' / (name + '.json')
    if not path.is_file(): raise RuntimeError('Unknown installation profile: ' + name)
    spec = registry.read(path)
    if spec.get('schema') != 1: raise RuntimeError('Unsupported profile schema: ' + name)
    result = dict(spec, install=[], check=[])
    for parent in spec.get('extends', []):
        inherited = load_profile(repo, parent, (*seen, name))
        if not set(spec['platforms']) <= set(inherited['platforms']):
            raise RuntimeError(name + ': parent does not support the selected platforms')
        for action in ('install', 'check'): result[action].extend(inherited[action])
    for action in ('install', 'check'): result[action].extend(spec.get(action, []))
    return result


def workflow(modules, action, args, repo, root, platform):
    profile = args[0] if args and not args[0].startswith('-') else ('steamdeck' if platform == 'steamdeck' else 'workstation')
    rest = args[1:] if args and args[0] == profile else args
    if rest:
        raise RuntimeError('Unexpected system arguments: ' + ' '.join(rest))
    spec = load_profile(repo, profile)
    if platform not in spec['platforms']:
        raise RuntimeError(profile + ' is not supported on ' + platform)
    steps, installed = [], set()
    entries = spec['check'] if action == 'check' else spec['install'] + spec['check']
    for item in entries:
        operation = item['action']
        if action == 'update' and operation == 'install':
            operation = 'update'
        planned = engine.plan(modules, item['module'], operation, item.get('args', []), repo, root, platform)
        for step in planned:
            key = (step['module'], step['action'], tuple(step['command']))
            if key in installed:
                continue
            steps.append(step); installed.add(key)
    return steps


def main(argv=None):
    parser = argparse.ArgumentParser(prog='workbench', description=__doc__)
    parser.add_argument('--prefix', type=Path, default=Path(os.environ.get('SOFTWARE_HOME', str(Path.home() / 'Software'))))
    parser.add_argument('--platform', choices=SUPPORTED, help='Preview another platform; execution on a different host is refused')
    parser.add_argument('--complete', choices=['modules', 'actions', 'targets'], help=argparse.SUPPRESS)
    parser.add_argument('--version', action='version', version=__version__)
    parser.add_argument('--json', action='store_true', help='Structured list/plan output')
    parser.add_argument('--plan', action='store_true', help='Resolve commands without executing or writing')
    parser.add_argument('module', nargs='?')
    parser.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        root = args.prefix.expanduser().resolve()
        host = detect()
        platform = args.platform or host
        modules = registry.discover(REPO, root)
        rest = args.args
        plan_only = args.plan or '--plan' in rest
        as_json = args.json or '--json' in rest
        rest = [a for a in rest if a not in ('--plan', '--json')]
        if args.complete:
            if args.complete == 'modules':
                print('\n'.join(name + ':' + spec['description'] for name, spec in modules.items()))
            elif args.module in modules:
                spec = modules[args.module]
                if args.complete == 'actions':
                    print('\n'.join(spec['actions']))
                elif rest and rest[0] in spec['actions']:
                    print('\n'.join(registry.targets(spec, rest[0], REPO)))
            return 0
        if args.module in (None, 'list'):
            data = [dict(name=name, description=spec['description'], platforms=spec['platforms'],
                         actions=list(spec['actions']), available=platform in spec['platforms']) for name, spec in modules.items()]
            if as_json:
                print(json.dumps(data, ensure_ascii=False, indent=2))
            else:
                print('workbench ' + __version__ + ' — ' + platform)
                for item in data:
                    print(f'{item["name"]:16} {item["description"]}' + ('' if item['available'] else ' [not available on this platform]'))
                    print('                 ' + ' '.join(item['actions']))
            return 0
        if args.module not in modules:
            raise RuntimeError('Unknown module: ' + args.module + '; run workbench list')
        spec = modules[args.module]
        if not rest or rest[0] in ('help', '-h', '--help'):
            print(f'workbench {args.module} ACTION [TARGET ...] [--plan]\n{spec["description"]}\nPlatforms: ' + ', '.join(spec['platforms']))
            for action, info in spec['actions'].items():
                print(f'  {action:12} {info["description"]}')
            return 0
        action, tail = rest[0], rest[1:]
        # Network's old service-first syntax is accepted during migration only.
        if args.module == 'network' and action in ('all', 'mihomo', 'tailscale', 'sc302') and tail:
            action, tail = tail[0], [action, *tail[1:]]
        if action not in spec['actions']:
            raise RuntimeError('Unsupported action: ' + action + '; choose ' + ', '.join(spec['actions']))
        if any(a in ('-h', '--help') for a in tail):
            print(f'workbench {args.module} {action} [TARGET ...] [--plan]\n' + spec['actions'][action]['description'])
            choices = registry.targets(spec, action, REPO)
            if choices:
                print('Targets: ' + ' '.join(choices))
            print('Options: --plan (read-only command plan); ' + spec['actions'][action].get('options', ''))
            return 0
        choices = registry.targets(spec, action, REPO)
        positional = tail[:next((i for i, arg in enumerate(tail) if arg.startswith('-')), len(tail))]
        if choices and any(value not in choices for value in positional):
            raise RuntimeError('Unknown target; choose: ' + ' '.join(choices))
        if args.module == 'system' and action in ('install', 'update', 'check'):
            steps = workflow(modules, action, tail, REPO, root, platform)
        else:
            steps = engine.plan(modules, args.module, action, tail, REPO, root, platform)
        if plan_only:
            if as_json:
                print(json.dumps(dict(platform=platform, prefix=str(root), steps=steps), ensure_ascii=False, indent=2))
            else:
                import shlex
                for step in steps:
                    print(f'{step["module"]:16} {step["action"]:10} ' + shlex.join(step['command']))
            return 0
        if platform != host:
            raise RuntimeError('--platform may only target another OS with --plan; actual host is ' + host)
        return engine.execute(steps, REPO, root, platform)
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print('workbench:', error, file=sys.stderr)
        return 1
