"""Conservative display-name supplement; never regenerate field IDs or storage layouts.

Match named struct/enum hashes against the installed type library. Primitive members
are named only when the entire containing struct's ordered type sequence matches.
In changed structs, only unique named struct/enum anchors are accepted; no LCS.
"""
import collections
import glob
import json
import os
import re
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, 'tl.py'), encoding='utf-8').read())
exec(open(os.path.join(HERE, 'zh.py'), encoding='utf-8').read())
SHAL = os.environ.get('SHALZUTH', os.path.join(HERE, 'HelldiversData'))
files = sorted(glob.glob(os.path.join(SHAL, 'data', 'components', '*.json')))
if not files:
    raise SystemExit('Missing shalzuth reference schemas: ' + SHAL)
SH = {}
for file in files:
    with open(file, encoding='utf-8') as f:
        SH.update(json.load(f))
ENUM_NAMES = {os.path.basename(p)[:-5] for p in glob.glob(os.path.join(SHAL, 'data', 'enums', '*.json'))}
SHH = {dh(n): n for n in SH}
PRIM = {'float': 8, 'uint': 6, 'ulong': 7, 'int': 2, 'byte': 4, 'ushort': 5}
STORAGE = {0: 'i8', 2: 'i32', 4: 'u8', 5: 'u16', 6: 'u32', 7: 'u64', 8: 'f32',
           12: 'enum', 14: 'u8', 16: 'enum', 17: 'u64'}
W.update({
    'unit_path': ('单位资源路径', '單位資源路徑'),
    'scale_min': ('最小缩放', '最小縮放'), 'scale_max': ('最大缩放', '最大縮放'),
    'radius': ('半径', '半徑'),
    'hidden_visibility_groups': ('生成时隐藏的可见组', '產生時隱藏的可見群組'),
    'show_random_visibility_group': ('生成时随机显示的可见组', '產生時隨機顯示的可見群組'),
    'on_hotjoin_corpse_repair_ability_patch': ('热加入时尸体修复能力', '熱加入時屍體修復能力'),
    'prefix': ('前缀', '前綴'), 'zones': ('区域', '區域'),
    'susceptibilities': ('状态易感配置', '狀態易感配置'),
    'damageable_zone_name': ('可受伤部位名称', '可受傷部位名稱'),
    'effect_node_name': ('特效节点名称', '特效節點名稱'),
    'volume_query_node_name': ('状态区域查询节点', '狀態區域查詢節點'),
    'volume_query_size_radius': ('状态区域查询半径', '狀態區域查詢半徑'),
    'status_effect_resistances': ('状态效果抗性', '狀態效果抗性'),
    'duration_scale': ('持续时间倍率', '持續時間倍率'),
})


def legacy_signature(v):
    name = v.get('subtype') if v.get('type') == 'array' else v.get('type')
    if name in PRIM:
        typ = ('primitive', PRIM[name])
    elif name in SH:
        typ = ('struct', dh(name))
    elif name in ENUM_NAMES:
        typ = ('enum', dh(name))
    else:
        return None
    return (v.get('type') == 'array', typ)


def current_signature(m):
    if m['atom'] == 3:
        return None  # a packed flag is not the old schema's byte
    if m['storage'] == 20:
        typ = ('struct', m['type'])
    elif m['storage'] in (12, 14, 16, 17):
        typ = ('enum', m['type'])
    elif m['storage'] in STORAGE:
        typ = ('primitive', m['storage'])
    else:
        return None
    return (m['atom'] in (1, 2), typ)


def pair(tid):
    ms = sorted(T[tid]['members'], key=lambda m: (m['offset'], m['count']))
    fs = list(SH.get(SHH.get(tid), {}).items())
    a = [current_signature(m) for m in ms]
    b = [legacy_signature(v) for _, v in fs]
    if fs and len(a) == len(b) and all(x is not None and x == y for x, y in zip(a, b)):
        return ms, {i: (fs[i], 'struct') for i in range(len(ms))}
    ca, cb = collections.Counter(a), collections.Counter(b)
    out = {}
    for i, sig in enumerate(a):
        if sig and sig[1][0] in ('struct', 'enum') and ca[sig] == cb[sig] == 1:
            out[i] = (fs[b.index(sig)], 'anchor')
    return ms, out


def label(name):
    en = name.replace('_', ' ')
    a, b = words(name)
    return [en[:1].upper() + en[1:], a, b]


def path_label(path, owner=None):
    # Keep array indices and named nested containers: otherwise thousands of
    # per-zone/per-status fields would acquire indistinguishable short labels.
    parts = path.split('.')
    labels = [[], [], []]
    for i, part in enumerate(parts):
        m = re.fullmatch(r'(.*?)(?:\[(\d+)\])?', part)
        name, index = m.groups()
        if i == 0 and len(parts) > 1:
            values = ['', '', '']  # the component's parameter-group header names it
        elif name.startswith('@'):
            values = ['', '', '']
        else:
            values = label(name)
            if i == len(parts)-1 and owner == 'CharacterVoiceComponent' and name == 'prefix':
                values = ['Voice prefix type', '语音前缀类型', '語音前綴類型']
        if index is not None:
            values = [(v + ' ' if v else '') + '#%d' % (int(index) + 1) for v in values]
        for n, value in enumerate(values):
            if value:
                labels[n].append(value)
    return [' · '.join(v) for v in labels]


def digest(tid):
    parts, seen = [], set()
    def visit(kind):
        if kind in seen:
            return
        seen.add(kind)
        t = T[kind]
        parts.append('%d:%d;' % (kind, t['size']))
        ms = sorted(t['members'], key=lambda m: (m['offset'], m['count']))
        for m in ms:
            parts.append('%d:%d:%d:%d:%d:%d;' % tuple(m[k] for k in ('offset', 'size', 'atom', 'storage', 'count', 'type')))
        for m in ms:
            if m['storage'] == 20 and m['type'] in T:
                visit(m['type'])
    visit(tid)
    h = 5381
    for c in ''.join(parts).encode():
        h = (h * 33 + c) % 4294967296
    return h


def walk(tid, base=0, path='', group=None, depth=0):
    assert depth < 32
    ms, pairs = pair(tid)
    out = []
    for i, m in enumerate(ms):
        pair_info = pairs.get(i)
        (name, info), evidence = pair_info if pair_info else ((None, {}), None)
        # Dynamic-array/pointer descriptors are never editable values.
        if m['atom'] == 1 or m['atom'] == 3:
            continue
        n = m['count'] if m['atom'] == 2 else 1
        if not n:
            continue
        offset = base + m['offset']
        segment = name or ('@%X' % offset)
        next_group = group or (name if depth == 0 else None)
        for index in range(n):
            at = offset + index * (m['size'] // n)
            seg = segment + ('[%d]' % index if m['atom'] == 2 else '')
            p = (path + '.' if path else '') + seg
            if m['storage'] == 20 and m['type'] in T:
                out.extend(walk(m['type'], at, p, next_group, depth + 1))
            elif name and m['storage'] in STORAGE:
                row = dict(offset=at, storage=STORAGE[m['storage']], name=p, labels=path_label(p, SHH.get(tid)),
                           description=info.get('description', ''), evidence=evidence,
                           owner=SHH.get(tid, '%08X' % tid), member=name)
                if next_group:
                    row['group'] = label(next_group)
                    row['group_key'] = next_group
                out.append(row)
    return out


def lua(value):
    if isinstance(value, str):
        return "'" + value.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('\r', '\\r') + "'"
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(x) for x in value) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'


root_file = os.path.join(HERE, '..', '..', 'offline', 'stratagem_entity_specs.lua')
roots = [(int(h, 16), int(size), name) for h, size, name in re.findall(
    r"\{0x([0-9A-F]+),(\d+),'([^']+)'\}", open(root_file, encoding='utf-8').read())]
commit = subprocess.check_output(['git', '-C', SHAL, 'rev-parse', 'HEAD'], text=True).strip()
lines = ['-- GENERATED by tools/component_gen/gen_reference_names.py. Display metadata only; saved IDs are unchanged.',
         '-- Source: https://github.com/shalzuth/HelldiversData/tree/' + commit,
         'local M={COMMIT=' + lua(commit) + ',TYPES={}}']
audit = []
for kind, size, name in roots:
    root = T[kind]['members'][1]['type']
    rows = walk(root)
    if not rows:
        continue
    entries = {str(r['offset']) + ':' + r['storage']: r for r in rows}
    lines.append('M.TYPES[0x%08X]=(function()return %s end)()' % (kind, lua(dict(size=size, record=root, signature=digest(root), fields=entries))))
    audit.append(dict(type=SHH.get(kind, name), hash='%08X' % kind, fields=len(rows),
                      complete_struct=sum(r['evidence'] == 'struct' for r in rows),
                      unique_named_anchor=sum(r['evidence'] == 'anchor' for r in rows)))
lines.append('return M')
output = os.path.join(HERE, '..', '..', 'offline', 'reference_component_names.lua')
with open(output, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')
shutil.copyfile(os.path.join(SHAL, 'LICENSE'), os.path.join(HERE, '..', '..', 'offline', 'REFERENCE_NAMES_LICENSE.txt'))
audit_file = os.environ.get('REFERENCE_NAMES_AUDIT', os.path.join(WORK, 'reference-names-audit.json'))
with open(audit_file, 'w', encoding='utf-8') as f:
    json.dump(dict(commit=commit, components=audit), f, ensure_ascii=False, indent=2)
print('Reference schemas:', len(SH), 'component tables:', len(audit), 'named inline positions:', sum(x['fields'] for x in audit))
