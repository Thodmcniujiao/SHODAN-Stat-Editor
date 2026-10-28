# Checks the 人物数据 page (src/stat_editor_offline.lua, KINDS[TYPES.avatar].DOC / MOVE / EXERTION) against the game:
# the AvatarComponentData record of the helldiver (content/fac_helldivers/cha_avatar/avatar_helldiver) is unrolled with
# the type library, every leaf compared with the RawData dump (in order, by value), then each row's offset and member
# name with that. Run after a game update:  python check_avatar_doc.py
#   COMPONENT_GEN_WORK: typelib.bin, entities.bin (see README.md);  RAWDATA: Darctor/Helldivers2_RawData
import os, re, json, struct
HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get('COMPONENT_GEN_WORK', os.path.join(HERE, 'work'))
RAW = os.environ.get('RAWDATA', os.path.join(HERE, 'Helldivers2_RawData'))
b = open(os.path.join(WORK, 'typelib.bin'), 'rb').read()
n32 = lambda o: struct.unpack_from('<I', b, o)[0]
nt, ne = n32(8), n32(12)
ts = 36 + 4 * (nt + ne); ms = ts + 36 * nt + 32 * ne
T = {}
for i in range(nt):
    at = ts + 36 * i; t = {'size': n32(at + 12), 'members': []}
    for j in range(n32(at + 28), n32(at + 28) + n32(at + 24)):
        m = ms + 72 * j
        t['members'].append(dict(atom=b[m + 12], storage=b[m + 13], count=b[m + 14] + b[m + 15] * 256, type=n32(m + 16), size=n32(m + 24), offset=n32(m + 40)))
    T[n32(36 + 4 * i)] = t
def leaves(tid, base=0):
    out = []
    for m in T[tid]['members']:
        n = m['count'] if m['atom'] == 2 else 1
        el = m['size'] // n if n else m['size']
        for k in range(n):
            o = base + m['offset'] + k * el
            if m['storage'] == 20 and m['type'] in T: out += leaves(m['type'], o)
            else: out.append((o, el, m['storage']))
    return out
E = open(os.path.join(WORK, 'entities.bin'), 'rb').read()
u32 = lambda o: struct.unpack_from('<I', E, o)[0]
B = {}; pos = 0
while pos < len(E):
    if E[pos + 4:pos + 8] != b'LDLD': pos += 4; continue
    B[u32(pos)] = (pos + 28, u32(pos + 16)); pos = pos + 28 + u32(pos + 16)
TYPE = 0x40EF204C
payload, _ = B[TYPE]; mp, arr = T[TYPE]['members']; row = T[arr['type']]['size']
at = None
for i in range(mp['count']):
    o = payload + mp['offset'] + i * 16
    if '%016X' % struct.unpack_from('<Q', E, o)[0] == '4D1C334D294DFA97': at = payload + arr['offset'] + u32(o + 8) * row
assert at, 'the helldiver has no AvatarComponentData'
dump = json.load(open(os.path.join(RAW, 'Data', 'entities', 'AvatarComponentData.json'), encoding='utf-8'))['entities'][0]
flat = []
def walk(x, p=''):
    if isinstance(x, dict):
        for k, v in x.items():
            if p == '' and k in ('hash', 'name', 'name_zh', 'index'): continue
            walk(v, p + '.' + k if p else k)
    elif isinstance(x, list):
        for i, v in enumerate(x): walk(v, '%s[%d]' % (p, i))
    else: flat.append((p, x))
walk(list(dump.values())[0])
L = leaves(arr['type'])
assert len(L) == len(flat), ('leaves', len(L), 'dump', len(flat))
member = {}
for (o, sz, st), (name, dv) in zip(L, flat):
    v = struct.unpack_from('<f', E, at + o)[0] if st == 8 else u32(at + o)
    if isinstance(dv, str): dv = int(dv.split()[0])
    assert abs(v - float(dv)) < 1e-4, (o, name, v, dv)
    member[o] = name
src = open(os.path.join(HERE, '..', '..', 'src', 'stat_editor_offline.lua'), encoding='utf-8').read()
doc = src[src.index('KINDS[TYPES.avatar].DOC = {'):src.index('KINDS[TYPES.avatar].EXERTION')]
rows = [(int(o), m) for o, m in re.findall(r"off = (\d+),[^\n]*?m = '([^']+)'", doc)]
ex = re.findall(r"\}, (\d+), '(\w+)' \}", src[src.index('KINDS[TYPES.avatar].add_exertion'):])
for i in range(8): rows += [(340 + i * 52 + int(d), 'exertion_levels[%d].%s' % (i, m)) for d, m in ex]
bad = [(o, m, member.get(o)) for o, m in rows if member.get(o) != m]
assert not bad, bad
print('AvatarComponentData: %d leaves equal to the dump; %d rows of 人物数据 at the right members' % (len(L), len(rows)))
