"""Small terminal renderer; machine output never goes through this module."""
import argparse
import os
import re
import shutil
import sys
import unicodedata

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
COLORS = {'title': '1;36', 'key': '36', 'ok': '32', 'warn': '33', 'error': '31', 'dim': '2'}


def width(value):
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1
               for c in ANSI.sub('', str(value)))


def wrap(value, limit):
    lines = []
    for paragraph in str(value).split('\n'):
        line = ''
        for token in re.findall(r'\S+\s*|\s+', paragraph):
            if line and width(line + token.rstrip()) > limit:
                lines.append(line.rstrip()); line = ''
            for char in token:
                if width(line + char) > limit:
                    lines.append(line.rstrip()); line = ''
                line += char
        lines.append(line.rstrip())
    return lines


class Console:
    def __init__(self, stream=None):
        self.stream = stream if stream is not None else sys.stdout
        self.color = (self.stream.isatty() and os.environ.get('TERM') != 'dumb'
                      and 'NO_COLOR' not in os.environ)
        self.columns = max(32, shutil.get_terminal_size((100, 24)).columns)

    def style(self, text, kind):
        return '\033[' + COLORS[kind] + 'm' + str(text) + '\033[0m' if self.color else str(text)

    def print(self, text=''):
        print(text, file=self.stream, flush=True)

    def title(self, text):
        self.print(self.style(text, 'title'))

    def table(self, rows):
        rows = [(str(a), str(b)) for a, b in rows]
        if not rows: return
        left = min(max(width(a) for a, _ in rows), max(12, self.columns // 3))
        right = max(8, self.columns - left - 4)
        for key, value in rows:
            keys, values = wrap(key, left), wrap(value, right)
            for i in range(max(len(keys), len(values))):
                a = keys[i] if i < len(keys) else ''
                b = values[i] if i < len(values) else ''
                b = re.sub(r'\[(OK|MISSING|PENDING|FAIL|当前平台不可用)\]',
                           lambda m: self.style(m[0], 'ok' if m[1] == 'OK' else 'warn' if m[1] in ('PENDING', '当前平台不可用') else 'error'), b)
                self.print('  ' + self.style(a, 'key') + ' ' * (left - width(a) + 2) + b)

    def status(self, label, message, kind='dim'):
        self.print(self.style('[' + label + ']', kind) + ' ' + message)


def notation(console):
    console.print(console.style('约定：<参数> 必填；[参数] 可选；... 可重复；a|b 表示任选其一。', 'dim'))


def component_help(console, name, spec, action=None, targets=()):
    info = spec['actions'][action] if action else spec
    arguments = info.get('arguments', spec.get('arguments', '[<target> ...]' if targets else ''))
    usage = 'workbench ' + name + ' ' + (action or '<action>')
    if not action:
        arguments = '[<target> ...] [options]'
    elif info.get('options'):
        arguments = ' '.join(filter(None, [arguments, *('[' + option + ']' for option in info['options'])]))
    console.title('用法')
    console.print('  ' + usage + (' ' + arguments if arguments else '') + ' [--plan [--json]]')
    console.print('  ' + info['description'])
    if not action:
        console.print()
        console.title('操作')
        console.table([(a, i['description']) for a, i in spec['actions'].items()])
    elif targets and arguments:
        console.print()
        console.title('可选对象')
        for line in wrap('  '.join(targets), console.columns - 2): console.print('  ' + line)
    console.print()
    console.title('选项')
    options = list(info.get('options', {}).items())
    options += [('--plan', '仅预览，不执行或写入'), ('--json', '与 --plan 一起使用，输出 JSON'),
                ('-h, --help', '显示帮助')]
    console.table(options)
    console.print()
    console.print(console.style('平台：' + ', '.join(info.get('platforms', spec['platforms'])), 'dim'))
    notation(console)
    if not action: console.print('详细参数：workbench ' + name + ' <action> --help')


class ArgumentParser(argparse.ArgumentParser):
    def print_help(self, file=None):
        console = Console(file)
        for line in self.format_help().rstrip().splitlines():
            console.print(console.style(line, 'title') if line.startswith('usage:') or line.endswith(':') else line)

    def error(self, message):
        console = Console(sys.stderr)
        console.print(self.format_usage().rstrip())
        console.status('ERROR', message, 'error')
        self.exit(2)
