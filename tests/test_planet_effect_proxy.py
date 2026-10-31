import asyncio
import copy
import json
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from test_galactic_effect_proxy import proxy, definition, flow, SOURCE


def live():
    return {1202: definition(), 1203: definition(1203, 71), 1397: definition(1397, 32)}


def plan(index=0, ids=None, icons=True):
    return dict(version=1, war_id=801, enabled=True,
                targets={str(index): dict(effects=ids if ids is not None else [1202], include_icons=icons)},
                definitions={str(i): {k: row[k] for k in ('effectType', 'nameHash')} for i, row in live().items()},
                icon_pairs={'1202': 1203})


def status():
    return dict(planetStatus=[dict(index=0, owner=1), dict(index=256, owner=3)],
                planetActiveEffects=[dict(index=256, galacticEffectId=999, metadata='preserve')],
                campaigns=[dict(id=100, planetIndex=0, count=1)], future={'unchanged': True})


class Assignments(unittest.TestCase):
    def test_additive_idempotent_and_never_mutates_other_state(self):
        original = status(); before = copy.deepcopy(original)
        out, count = proxy.patch_status(original, plan(ids=[1202, 1397, 1202]), live(), 801)
        self.assertEqual(count, 3)
        self.assertEqual(out['planetActiveEffects'], before['planetActiveEffects'] + [
            {'index': 0, 'galacticEffectId': 1202}, {'index': 0, 'galacticEffectId': 1203},
            {'index': 0, 'galacticEffectId': 1397}])
        self.assertEqual(original, before)
        for key in ('planetStatus', 'campaigns', 'future'):
            self.assertEqual(out[key], original[key])
        again, count = proxy.patch_status(out, plan(ids=[1202, 1397]), live(), 801)
        self.assertEqual(count, 0); self.assertIs(again, out)

    def test_optional_icon_and_no_reverse_pairing(self):
        for ids, icons, expected in [([1202], False, [1202]), ([1203], True, [1203]),
                                     ([1202, 1203], True, [1202, 1203])]:
            with self.subTest(ids=ids, icons=icons):
                out, count = proxy.patch_status(status(), plan(ids=ids, icons=icons), live(), 801)
                self.assertEqual([r['galacticEffectId'] for r in out['planetActiveEffects'][1:]], expected)
                self.assertEqual(count, len(expected))

    def test_all_273_current_planet_indices(self):
        text = (SOURCE.parents[1] / 'planet_effect_data.lua').read_text(encoding='utf-8')
        data = json.loads(text.split('[===[\n', 1)[1].rsplit(']===]', 1)[0])
        indices = [p['index'] for p in data['planets']]
        self.assertEqual(len(indices), 273)
        document = dict(planetStatus=[dict(index=p) for p in indices], planetActiveEffects=[])
        config = plan();config['targets'] = {str(p): dict(effects=[1202], include_icons=True) for p in indices}
        out, count = proxy.patch_status(document, config, live(), data['war_id'])
        self.assertEqual(count, 546)
        self.assertEqual({r['index'] for r in out['planetActiveEffects']}, set(indices))

    def test_invalid_target_or_id_rolls_back_entire_body(self):
        source = status()
        cases = []
        p = plan();p['targets']['999999'] = dict(effects=[1397], include_icons=True);cases.append(p)
        p = plan(ids=[1202, 123456]);cases.append(p)
        p = plan();p['definitions']['1202']['nameHash'] += 1;cases.append(p)
        p = plan();p['definitions']['1203']['effectType'] = 40;cases.append(p)
        p = plan();p['icon_pairs']['1202'] = 1397;cases.append(p)
        p = plan();p['war_id'] = 802;cases.append(p)
        p = plan(ids=[True]);cases.append(p)
        for config in cases:
            with self.subTest(config=config):
                before = copy.deepcopy(source)
                with self.assertRaises(ValueError):proxy.patch_status(source, config, live(), 801)
                self.assertEqual(source, before)
        with self.assertRaises(ValueError):proxy.patch_status(source, plan(), None, 801)

    def test_disabled_empty_and_incompatible_schemas(self):
        p = plan();p['enabled'] = False
        source = status();out, count = proxy.patch_status(source, p, None, 801)
        self.assertIs(out, source);self.assertEqual(count, 0)
        p=plan();p['targets']['999999']=dict(effects=[],include_icons=False)
        _, count=proxy.patch_status(status(),p,live(),801);self.assertEqual(count,2)
        for source in [None, {}, {'planetStatus': [], 'planetActiveEffects': None},
                       {'planetStatus': [{'index': 0}], 'planetActiveEffects': [None]},
                       {'planetStatus': [{'index': 0}, {'index': 0}], 'planetActiveEffects': []}]:
            with self.subTest(source=source):
                with self.assertRaises(ValueError):proxy.patch_status(source, plan(), live(), 801)

    def test_status_hook_preserves_auth_and_other_endpoints(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp);path = root / 'planet_effects.json';path.write_text(json.dumps(plan()), encoding='utf-8')
            addon = proxy.EffectDefinitionsAddon(root / 'definitions.json', path)
            addon.current_catalog = live();addon.catalogue_at = time.monotonic()
            f = flow(url=f'https://{proxy.HOST}/api/WarSeason/801/Status', body=json.dumps(status()))
            addon.request(f);self.assertEqual(f.request.headers['authorization'], 'test-placeholder')
            self.assertNotIn('if-none-match', f.request.headers)
            addon.response(f)
            self.assertEqual(len(json.loads(f.response.text)['planetActiveEffects']), 3)
            report = json.loads((root / 'WarProxy/planet_effect_status.json').read_text(encoding='utf-8'))
            self.assertEqual(report['added'], 2)
            for url, method, code in [
                (f'https://{proxy.HOST}/api/WarSeason/801/WarInfo','GET',200),
                (f'https://{proxy.HOST}/api/WarSeason/801/Status','POST',200),
                (f'https://{proxy.HOST}/api/WarSeason/801/Status','GET',304),
                (f'https://{proxy.HOST}.example/api/WarSeason/801/Status','GET',200),
                (f'https://{proxy.HOST}/api/WarSeason/801/Operation','GET',200)]:
                f = flow(url=url, method=method, body=json.dumps(status()), status=code);old = f.response.text
                addon.response(f);self.assertEqual(f.response.text, old)

    def test_missing_or_stale_live_catalogue_never_uses_bundled_names_as_authority(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp);path = root / 'planet_effects.json';path.write_text(json.dumps(plan()), encoding='utf-8')
            addon = proxy.EffectDefinitionsAddon(root / 'definitions.json', path)
            f = flow(url=f'https://{proxy.HOST}/api/WarSeason/801/Status', body=json.dumps(status()));old = f.response.text
            addon.response(f);self.assertEqual(f.response.text, old)
            addon.current_catalog = live();addon.catalogue_at = time.monotonic() - 4000
            addon.response(f);self.assertEqual(f.response.text, old)

    def test_background_fetch_is_mocked_and_does_not_block_status(self):
        async def scenario(root):
            path = root / 'planet_effects.json';path.write_text(json.dumps(plan()), encoding='utf-8')
            addon = proxy.EffectDefinitionsAddon(root / 'definitions.json', path)
            async def heartbeat_stub():pass
            addon.heartbeat=heartbeat_stub
            with patch.object(addon, 'prepare_revocation'), patch.object(proxy, 'fetch_catalogue', return_value=live()) as fetch:
                addon.running();self.assertIsNotNone(addon.catalogue_task)
                await addon.catalogue_task;fetch.assert_called_once()
            self.assertEqual(addon.current_catalog, live())
        with tempfile.TemporaryDirectory() as temp:asyncio.run(scenario(Path(temp)))


if __name__ == '__main__':unittest.main()
