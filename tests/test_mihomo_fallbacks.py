import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'libexec'))
import mihomo_deck
from mihomo_overrides import apply_fallbacks


class FallbackPolicyTests(unittest.TestCase):
    def setUp(self):
        self.provider = {
            'proxies': [{'name': n, 'type': 'ss'} for n in ('hk-a', 'hk-b', 'jp-a')],
            'proxy-groups': [
                {'name': 'Hong Kong', 'type': 'select', 'proxies': ['hk-a', 'hk-b']},
                {'name': 'Games', 'type': 'select', 'proxies': ['DIRECT', 'Hong Kong', 'jp-a']},
                {'name': 'Other', 'type': 'select', 'proxies': ['Hong Kong', 'jp-a']},
            ],
            'rules': ['GEOSITE,steam@cn,DIRECT', 'GEOSITE,steam,Games', 'MATCH,Other'],
        }
        self.spec = {'name': 'HK fallback', 'source': 'Hong Kong', 'attach-to': 'Games',
                     'preferred': 'hk-b', 'url': 'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/'}

    def apply(self, config=None, spec=None):
        config = copy.deepcopy(self.provider if config is None else config)
        apply_fallbacks(config, {'schema': 1, 'fallback': [self.spec if spec is None else spec]})
        return config

    def test_fallback_is_scoped_and_preserves_other_groups_and_routes(self):
        config = self.apply()
        self.assertEqual(config['rules'], self.provider['rules'])
        self.assertEqual(config['proxy-groups'][0], self.provider['proxy-groups'][0])
        self.assertEqual(config['proxy-groups'][2], self.provider['proxy-groups'][2])
        self.assertEqual(config['proxy-groups'][1]['proxies'], ['HK fallback', 'DIRECT', 'Hong Kong', 'jp-a'])
        group = config['proxy-groups'][-1]
        self.assertEqual(group['proxies'], ['hk-b', 'hk-a'])
        self.assertEqual(group['type'], 'fallback')
        self.assertEqual(group['expected-status'], '200')
        self.assertEqual((group['interval'], group['timeout'], group['lazy']), (180, 8000, False))

    def test_refresh_rebuilds_scope_without_retaining_removed_nodes(self):
        updated = copy.deepcopy(self.provider)
        updated['proxies'].append({'name': 'hk-new', 'type': 'ss'})
        updated['proxy-groups'][0]['proxies'] = ['hk-new', 'hk-a']
        self.assertEqual(self.apply(updated)['proxy-groups'][-1]['proxies'], ['hk-new', 'hk-a'])

    def test_nested_direct_dynamic_and_empty_sources_are_rejected(self):
        for mutation in ({'proxies': ['DIRECT', 'hk-a']}, {'proxies': ['Other']},
                         {'proxies': []}, {'use': ['provider']}, {'include-all': True},
                         {'filter': 'HK'}):
            with self.subTest(mutation=mutation):
                config = copy.deepcopy(self.provider)
                config['proxy-groups'][0].update(mutation)
                with self.assertRaises(ValueError):
                    self.apply(config)

    def test_missing_groups_collisions_and_invalid_options_fail_closed(self):
        for mutation in ({'source': 'missing'}, {'attach-to': 'missing'}, {'name': 'Games'},
                         {'name': 'hk-a'}, {'name': 'DIRECT'}, {'attach-to': 'Hong Kong'},
                         {'timeout': True}, {'interval': 0}, {'url': 'http://example.com/'},
                         {'unknown': True}):
            with self.subTest(mutation=mutation):
                with self.assertRaises(ValueError):
                    self.apply(spec=dict(self.spec, **mutation))

    def test_compose_reapplies_local_toml_without_mutating_subscription(self):
        original = copy.deepcopy(self.provider)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            policy = root / 'config/mihomo/fallbacks.toml'
            policy.parent.mkdir(parents=True)
            policy.write_text('schema = 1\n[[fallback]]\n' + '\n'.join(
                f'{key} = {json.dumps(value)}' for key, value in self.spec.items()))
            first = mihomo_deck.compose(self.provider, root, '100.100.1.4')
            refreshed = mihomo_deck.compose(self.provider, root, '100.100.1.4')
        self.assertEqual(first, refreshed)
        self.assertEqual(first['proxy-groups'][-1]['proxies'], ['hk-b', 'hk-a'])
        self.assertEqual(self.provider, original)


if __name__ == '__main__':
    unittest.main()
