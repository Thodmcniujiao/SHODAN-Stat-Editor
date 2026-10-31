import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

SOURCE = Path(__file__).resolve().parents[1] / 'offline/network/galactic_effect_proxy.py'
spec = importlib.util.spec_from_file_location('galactic_proxy', SOURCE)
proxy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proxy)


def definition(effect_id=1202, kind=40):
    return dict(id=effect_id, gameplayEffectId32=0, effectType=kind, flags=1,
                nameHash=529482282, descriptionFluffHash=0,
                descriptionGamePlayLongHash=0, descriptionGamePlayShortHash=0,
                valueTypes=[16, 0], values=[2922304745, 0])


def plan(row, **changes):
    return dict(version=1, enabled=True, effects={str(row['id']):
                dict(enabled=True, base=copy.deepcopy(row), changes=changes)})


class Response:
    def __init__(self, body, status=200):
        self.text, self.status_code = body, status
        self.headers = {'etag': 'old', 'last-modified': 'old', 'cache-control': 'public'}

    def get_text(self, strict=True):
        return self.text


def flow(url='https://' + proxy.HOST + '/api/WarSeason/GalacticWarEffects', method='GET', body=None, status=200):
    return SimpleNamespace(request=SimpleNamespace(pretty_url=url, method=method,
                           headers={'if-none-match': 'original', 'authorization': 'test-placeholder'}),
                           response=Response(body if body is not None else json.dumps([definition()]), status))


class Definitions(unittest.TestCase):
    def test_actual_id_and_icon_remain_separate(self):
        actual, icon = definition(), definition(1203, 71)
        source = [actual, icon]
        out, ids = proxy.patch_definitions(source, plan(actual, values=[2313485354, 0]))
        self.assertEqual(ids, [1202])
        self.assertEqual(out[0]['values'], [2313485354, 0])
        self.assertEqual(out[1], icon)
        self.assertEqual(actual['values'], [2922304745, 0])

    def test_preserves_unknown_server_fields_and_envelope(self):
        row = dict(definition(), future={'keep': True})
        source = {'galacticEffects': [row], 'future': [12]}
        out, ids = proxy.patch_definitions(source, plan(row, flags=3))
        self.assertEqual(ids, [1202])
        self.assertEqual(out['future'], [12])
        self.assertEqual(out['galacticEffects'][0]['future'], row['future'])

    def test_every_baseline_field_protects_against_updates(self):
        row = definition()
        for key in proxy.FIELDS:
            with self.subTest(key=key):
                changed = copy.deepcopy(row)
                changed[key] = [987, 0] if key in {'values', 'valueTypes'} else row[key] + 1
                out, ids = proxy.patch_definitions([changed], plan(row, flags=7))
                self.assertEqual(ids, [])
                self.assertEqual(out, [changed])

    def test_bad_fields_and_shapes_never_apply(self):
        row = definition()
        cases = [{'id': 1203}, {'unknown': 1}, {'flags': True}, {'flags': -1},
                 {'flags': 2**32}, {'flags': 1.5}, {'values': [float('nan')]},
                 {'values': [float('inf')]}, {'values': [True]}, {'values': {}},
                 {'values': [10**400]}, {'valueTypes': [1.5]}, {'valueTypes': [-1]}]
        for changes in cases:
            with self.subTest(changes=changes):
                self.assertEqual(proxy.patch_definitions([row], plan(row, **changes)), ([row], []))
        config = plan(row, flags=3)
        config['effects']['1202']['base']['id'] = 1203
        self.assertEqual(proxy.patch_definitions([row], config), ([row], []))

    def test_both_switches_and_unique_current_id_required(self):
        row = definition()
        config = plan(row, flags=7)
        for level in ['enabled', 'entry']:
            altered = copy.deepcopy(config)
            if level == 'enabled':
                altered['enabled'] = False
            else:
                altered['effects']['1202']['enabled'] = False
            self.assertEqual(proxy.patch_definitions([row], altered), ([row], []))
        self.assertEqual(proxy.patch_definitions([row, row], config), ([row, row], []))
        self.assertEqual(proxy.patch_definitions([definition(1203, 71)], config), ([definition(1203, 71)], []))

    def test_wire_values_have_no_arbitrary_slider_limit(self):
        row = definition()
        out, ids = proxy.patch_definitions([row], plan(row, values=[-1e100, 1e100]))
        self.assertEqual(ids, [1202])
        self.assertEqual(out[0]['values'], [-1e100, 1e100])

    def test_response_hook_and_disabled_or_corrupt_plan(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'portable.json'
            path.write_text(json.dumps(plan(definition(), values=[2313485354, 0])), encoding='utf-8')
            addon = proxy.EffectDefinitionsAddon(path)
            f = flow()
            addon.request(f)
            self.assertNotIn('if-none-match', f.request.headers)
            self.assertEqual(f.request.headers['authorization'], 'test-placeholder')
            addon.response(f)
            self.assertEqual(json.loads(f.response.text)[0]['values'], [2313485354, 0])
            self.assertNotIn('etag', f.response.headers)
            self.assertEqual(f.response.headers['cache-control'], 'no-store')
            for contents in ['{broken', json.dumps({'version': 1, 'enabled': False, 'effects': {}})]:
                path.write_text(contents, encoding='utf-8')
                f = flow(); old = f.response.text
                addon.request(f); addon.response(f)
                self.assertEqual(f.response.text, old)
                self.assertEqual(f.request.headers['if-none-match'], 'original')

    def test_endpoint_guards_preserve_original_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'plan.json'
            path.write_text(json.dumps(plan(definition(), flags=3)), encoding='utf-8')
            addon = proxy.EffectDefinitionsAddon(path)
            for url, method, status in [
                (f'https://{proxy.HOST}/api/WarSeason/801/Status', 'GET', 200),
                (f'https://{proxy.HOST}/api/WarSeason/801/WarInfo', 'GET', 200),
                (f'https://{proxy.HOST}/api/WarSeason/GalacticWarEffects', 'POST', 200),
                (f'https://{proxy.HOST}/api/WarSeason/GalacticWarEffects', 'GET', 304),
                ('https://login.example/GalacticWarEffects', 'GET', 200),
                (f'https://{proxy.HOST}.example/api/WarSeason/GalacticWarEffects', 'GET', 200),
                (f'http://{proxy.HOST}/api/WarSeason/GalacticWarEffects', 'GET', 200),
            ]:
                with self.subTest(url=url, method=method, status=status):
                    f = flow(url, method, status=status); old = f.response.text
                    addon.response(f)
                    self.assertEqual(f.response.text, old)
                    self.assertEqual(f.response.headers['etag'], 'old')
            for body in ['not json', '{}', '[null]', json.dumps([definition(), definition()])]:
                f = flow(body=body); addon.response(f)
                self.assertEqual(f.response.text, body)

    def test_snapshot_can_be_consumed_without_mitmproxy(self):
        path = SOURCE.parents[1] / 'galactic_effect_data.lua'
        text = path.read_text(encoding='utf-8')
        data = json.loads(text.split('[===[\n', 1)[1].rsplit(']===]', 1)[0])
        rows = [entry['definition'] for entry in data['effects']]
        self.assertTrue(all(proxy.valid_definition(row) for row in rows))
        for row in rows:
            out, ids = proxy.patch_definitions(rows, plan(row, flags=(row['flags'] + 1) % 2**32))
            self.assertEqual(ids, [row['id']])
            self.assertEqual(sum(a != b for a, b in zip(rows, out)), 1)


if __name__ == '__main__':
    unittest.main()
