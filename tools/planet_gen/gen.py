# Regenerates offline/planet_data.lua's names: every member of the planet settings types (current type library)
# matched to the 2025 settings dump of shalzuth/HelldiversData by value across every record, then by order and kind;
# names an earlier member-order pairing gave are kept where the values do not say otherwise. Adds the Chinese
# labels of every name; planets' display names use independently resolved native localization IDs.
#
#   python gen.py            (environment: see README.md)
import os, sys, json, re, struct, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import luatable
from aligner import Aligner, records

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
# the layout of every planet settings type (from the type library) and the earlier names: the input; the output adds
# the names matched here, their source, the Chinese labels and the planet names
DATA = os.environ.get('PLANET_DATA', os.path.join(HERE, 'planet_data.base.lua'))
OUT = os.environ.get('OUT', os.path.join(ROOT, 'offline', 'planet_data.lua'))
WORK = os.environ.get('COMPONENT_GEN_WORK', os.path.join(HERE, '..', 'component_gen', 'work'))     # decrypted .dl_bin files
SHAL = os.environ.get('SHALZUTH', os.path.join(HERE, '..', 'component_gen', 'HelldiversData'))

exec(open(os.path.join(HERE, '..', 'component_gen', 'zh.py'), encoding='utf-8').read())
from planet_zh import PZ, PW
Z.update(PZ); W.update(PW)

base = luatable.parse(open(DATA, encoding='utf-8').read())
S = base['schemas']
for e in base['enums'].values():
    if not isinstance(e.get('labels'), dict): e['labels'] = {}   # (an empty table reads back as a list)
EN = {k: v['name'] for k, v in base['enums'].items()}


def murmur64a(key, seed=0):
    m = 0xc6a4a7935bd1e995; r = 47; M = (1 << 64) - 1; n = len(key); h = (seed ^ (n * m)) & M; i = 0
    while n - i >= 8:
        k = struct.unpack_from('<Q', key, i)[0]; k = (k * m) & M; k ^= k >> r; k = (k * m) & M; h ^= k; h = (h * m) & M; i += 8
    rem = n - i
    for j in range(rem - 1, -1, -1): h ^= key[i + j] << (8 * j)
    if rem: h = (h * m) & M
    h ^= h >> r; h = (h * m) & M; h ^= h >> r
    return h


# ------------------------------------------------------------------ names by value
prior = {(t, i): m['alias'] for t, s in S.items() for i, m in enumerate(s['members']) if m.get('alias')}
A = Aligner(S, base['roots'], os.path.join(SHAL, 'data', 'settings') + os.sep, WORK + os.sep, enum_names=EN, prior=prior)
res = A.run()
stats = collections.Counter()
for t, (pairs, keys) in res.items():
    ms = S[t]['members']
    claimed = {v[0] for v in pairs.values() if v[1].startswith('value')}
    for i, m in enumerate(ms):
        new, old = pairs.get(i), m.get('alias')
        m.pop('legacy_exact', None)
        if new and new[1].startswith('value'):
            if old and old != new[0]: m['description'] = None
            m['alias'], m['source'], m['agree'] = new[0], new[1], round(new[2], 3)
        elif old and old not in claimed:
            m['source'] = 'order' if new and new[0] == old else 'legacy'
        elif new:
            m['alias'], m['source'], m['description'] = new[0], 'order', None
        else:
            m.pop('alias', None); m['source'] = 'none'; m['description'] = None
        stats[m['source']] += 1
for t, s in S.items():
    if t not in res:
        for m in s['members']:
            m.pop('legacy_exact', None)
            m['source'] = 'legacy' if m.get('alias') else 'none'
            stats['untouched ' + m['source']] += 1

# ------------------------------------------------------------------ enum names seen with their values
for t, mp in A.enum_maps.items():
    e = base['enums'].get(t)
    if not e: continue
    for v, names in mp.items():
        name, n = names.most_common(1)[0]
        if n < 0.8 * sum(names.values()): continue
        e['labels'][str(v)] = {'label': name, 'source': '2025 values'}
        stats['enum values seen'] += 1

for e in base['enums'].values():   # (a name seen with another value is no longer guessed for this one)
    seen = {x['label'] for x in e['labels'].values() if x.get('source') == '2025 values'}
    for v in [v for v, x in e['labels'].items() if x.get('source') != '2025 values' and x['label'] in seen]:
        del e['labels'][v]; stats['enum guesses dropped'] += 1

# ------------------------------------------------------------------ Chinese labels
def zh_of(name):
    if name in W: return W[name]
    a, b = words(name)
    return a, b
labels = {}
for s in S.values():
    for m in s['members']:
        if m.get('alias'): labels[m['alias']] = list(zh_of(m['alias']))
left = sorted({w for n, (a, b) in labels.items() for w in re.findall(r'[a-z]{2,}', a.replace('Wwise', ''))})
if left: print('untranslated words:', ' '.join(left))

# ------------------------------------------------------------------ planet names
# Names must come from the native locale, never OpenCC or a phonetic guess.
# Generate offline/localization_data.lua first with tools/update_game_localizations.py.
localization_path = os.path.join(ROOT, 'offline', 'localization_data.lua')
localized = json.loads(open(localization_path, encoding='utf-8').read().split('[===[', 1)[1].split(']===]', 1)[0])
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from update_game_localizations import planet_names
planets = planet_names(localized)
stats['planets named'] = len(planets)

base['zh'] = labels
base['planets'] = planets
base['naming'] = {'source': 'shalzuth/HelldiversData data/settings (2025-09)', 'stats': dict(stats)}
head = ('-- Generated from the installed type library by tools/planet_gen/gen.py; names matched by value to the 2025 settings\n'
        '-- of shalzuth/HelldiversData (source per member: value / value-constant / order / legacy / none).\n')
open(OUT, 'w', encoding='utf-8', newline='\n').write(head + 'return ' + luatable.dump(base) + '\n')
print(dict(stats))
