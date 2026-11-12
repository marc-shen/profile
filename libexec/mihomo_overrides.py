"""Local fallback policies composed from the current subscription's node groups."""
from urllib.parse import urlsplit


def apply_fallbacks(config, policy):
    if policy.get('schema') != 1 or set(policy) - {'schema', 'fallback'}:
        raise ValueError('fallbacks.toml: expected schema = 1 and [[fallback]] entries')
    entries = policy.get('fallback', [])
    if not isinstance(entries, list):
        raise ValueError('fallbacks.toml: fallback must be an array of tables')
    # Resolve sources only from the subscription, never from another local group.
    groups = {g['name']: g for g in config['proxy-groups']}
    nodes = {p['name'] for p in config.get('proxies', [])}
    reserved = set(groups) | nodes | {'DIRECT', 'REJECT', 'GLOBAL', 'COMPATIBLE'}
    allowed = {'name', 'source', 'attach-to', 'preferred', 'url', 'interval', 'timeout'}
    for spec in entries:
        if not isinstance(spec, dict) or set(spec) - allowed:
            raise ValueError('fallbacks.toml: unsupported fallback option')
        for key in ('name', 'source', 'attach-to', 'url'):
            if not isinstance(spec.get(key), str) or not spec[key].strip():
                raise ValueError('fallbacks.toml: missing ' + key)
        name = spec['name']
        if name in reserved:
            raise ValueError('fallbacks.toml: fallback name already exists')
        source = groups.get(spec['source'])
        target = groups.get(spec['attach-to'])
        if source is None or target is None:
            raise ValueError('fallbacks.toml: source or destination group no longer exists')
        if source is target or target.get('type') != 'select' or not isinstance(target.get('proxies'), list):
            raise ValueError('fallbacks.toml: destination must be a separate explicit select group')
        # Do not accidentally broaden a regional pool through nested groups,
        # DIRECT, proxy providers, regex expansion or include-all settings.
        if any(source.get(k) for k in ('use', 'filter', 'exclude-filter', 'exclude-type',
                                      'include-all', 'include-all-proxies', 'include-all-providers')):
            raise ValueError('fallbacks.toml: source must contain explicit subscription nodes')
        members = source.get('proxies')
        if not isinstance(members, list) or not members or any(n not in nodes for n in members):
            raise ValueError('fallbacks.toml: source must contain only explicit subscription nodes')
        members = list(dict.fromkeys(members))
        preferred = spec.get('preferred')
        if preferred is not None and not isinstance(preferred, str):
            raise ValueError('fallbacks.toml: preferred must be a node name')
        if preferred in members:
            members.remove(preferred)
            members.insert(0, preferred)
        # A renamed/removed preferred node is ignored, never reintroduced.
        url = urlsplit(spec['url'])
        if url.scheme != 'https' or not url.hostname or url.username or url.password:
            raise ValueError('fallbacks.toml: health check must use an HTTPS URL without credentials')
        interval, timeout = spec.get('interval', 180), spec.get('timeout', 8000)
        if type(interval) is not int or not 30 <= interval <= 86400:
            raise ValueError('fallbacks.toml: interval must be 30..86400 seconds')
        if type(timeout) is not int or not 1000 <= timeout <= 60000:
            raise ValueError('fallbacks.toml: timeout must be 1000..60000 milliseconds')
        config['proxy-groups'].append({
            'name': name, 'type': 'fallback', 'proxies': members,
            'url': spec['url'], 'expected-status': '200',
            'interval': interval, 'timeout': timeout, 'lazy': False,
        })
        target['proxies'].insert(0, name)
        reserved.add(name)
