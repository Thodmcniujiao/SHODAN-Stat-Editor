"""Identity/provenance regression tests; no API or installed game required."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from update_game_localizations import build, annotate_effects, LANGUAGES


class NativeNames(unittest.TestCase):
    def setUp(self):
        self.extracted = {'conflicts': [], 'planets': [
            {'debug': 'planet_999', 'name_hash': 101, 'settings_hash': 11},
            {'debug': 'homeworld', 'name_hash': 102, 'settings_hash': 12}],
            'presence': [], 'languages': {
                LANGUAGES['en']: {'101': 'FIRST', '102': 'SECOND'},
                LANGUAGES['zhs']: {'101': '简体原译', '102': '另一个原译'},
                LANGUAGES['zht']: {'101': '完全不同譯名', '102': '第二'}}}
        self.war = {'planetInfos': [{'index': 2, 'settingsHash': 11}, {'index': 3, 'settingsHash': 999}]}
        self.community = {'3': {'name': 'Second'}}

    def generate(self):
        return build(self.extracted, self.war, self.community, [])

    def test_index_is_not_debug_suffix_and_locales_are_independent(self):
        d = self.generate()
        self.assertEqual(d['api_planets']['2']['local_debug'], 'planet_999')
        self.assertEqual(d['api_planets']['3']['source'], 'api_english_exact')
        self.assertEqual(d['api_planets']['3']['settings_hash'], 999)
        self.assertEqual(d['strings']['zhs']['101'], '简体原译')

    def test_similar_english_is_not_a_match(self):
        self.community['3']['name'] = 'Second Prime'
        with self.assertRaises(AssertionError):
            self.generate()

    def test_ambiguous_exact_english_is_rejected(self):
        self.extracted['planets'].append({'debug': 'other', 'name_hash': 103, 'settings_hash': 13})
        self.extracted['languages'][LANGUAGES['en']]['103'] = 'SECOND'
        with self.assertRaises(AssertionError):
            self.generate()

    def test_duplicate_records_and_unknown_texts_remain_distinct(self):
        self.extracted['planets'].append(dict(self.extracted['planets'][0]))
        self.extracted['planets'].append({'debug': 'homeworld', 'name_hash': 103, 'settings_hash': 12})
        d = self.generate()
        self.assertEqual(d['coverage']['local_records'], 4)
        self.assertEqual(len(d['planets']['homeworld']), 2)
        self.assertNotIn('103', d['strings']['zhs'])

    def test_conflicting_native_texts_are_rejected(self):
        self.extracted['conflicts'] = [{'id': 101}]
        with self.assertRaises(AssertionError):
            self.generate()

    def test_direct_description_hash_can_identify_unlabelled_effect(self):
        d = self.generate()
        effects = [{'definition': {'id': 1234, 'effectType': 32, 'values': [1],
                    'nameHash': 999, 'descriptionGamePlayShortHash': 101,
                    'descriptionGamePlayLongHash': 0, 'descriptionFluffHash': 0}}]
        original = copy.deepcopy(effects[0]['definition'])
        annotate_effects(effects, d, [])
        self.assertEqual(effects[0]['name_zh'], '简体原译')
        self.assertEqual(effects[0]['text_provenance']['zhs']['name']['source'], 'description')
        self.assertEqual(effects[0]['unresolved_text_hashes']['zhs']['nameHash'], 999)
        self.assertEqual(effects[0]['definition'], original)

    def test_ambiguous_local_hash_is_not_used(self):
        d = self.generate()
        d['presence']['44'] = [{'debug': 'one', 'name_hash': 101}, {'debug': 'two', 'name_hash': 102}]
        effect = {'definition': {'id': 1234, 'effectType': 71, 'values': [44],
                  'nameHash': 999, 'descriptionGamePlayShortHash': 998,
                  'descriptionGamePlayLongHash': 0, 'descriptionFluffHash': 0}}
        annotate_effects([effect], d, [])
        self.assertNotIn('name_zh', effect)


if __name__ == '__main__':
    unittest.main()
