"""Current entity component registry and full named specs used by Armory > Stratagem editing.

Uses the same local type library and RawData alignment as gen.py. Dynamic arrays,
strings and unsupported primitive widths are handled as read-only descriptors by
the runtime reflector, never exposed as editable pointer words.
"""
import os, re, json
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'gen.py'), encoding='utf-8').read()
head, tail = src.split("L=['-- GENERATED", 1)
exec(head)
# The generic weapon generator only handles inline members. Explicitly keep
# pointer descriptors out of these specs; the runtime displays them separately.
walk_source = open(os.path.join(HERE, 'walk.py'), encoding='utf-8').read()
walk_source = walk_source[walk_source.index('def walk('):walk_source.index('def fields(')]
walk_source = walk_source.replace("        name=ks[i] if ks else None", "        if m['atom']==1 or m['storage'] not in (2,4,6,7,8,12,14,16,17,20): continue\n        name=ks[i] if ks else None")
exec(walk_source)
COMP_INFO = {
 'VehicleComponentData': ('vehicle', '载具', '載具', 'Vehicle'),
 'DepositComponentData': ('deposit', '背包补给与释放', '背包補給與釋放', 'Deposit'),
 'TargetingComponentData': ('targeting', '瞄准目标', '瞄準目標', 'Targeting'),
 'SeekingMissileComponentData': ('seeking_missile', '追踪导弹', '追蹤導彈', 'Seeking missile'),
 'ExplosiveComponentData': ('explosive', '爆炸实体', '爆炸實體', 'Explosive entity'),
 'DisplacementComponentData': ('displacement', '位移', '位移', 'Displacement'),
 'StickyComponentData': ('sticky', '附着', '附著', 'Sticky'),
 'LoadoutPackageComponentData': ('loadout_package', '配装资源包', '配裝資源包', 'Loadout package'),
 'EnemyPackageComponentData': ('enemy_package', '实体资源包', '實體資源包', 'Entity package'),
 'EncyclopediaEntryComponentData': ('encyclopedia_entry', '百科条目', '百科條目', 'Encyclopedia entry'),
}
SUBOF = {name: 'stratagem' for name in COMP_INFO}
tail = "L=['-- GENERATED" + tail
tail = tail.replace('tools/component_gen/gen.py: do not edit by hand.', 'tools/component_gen/gen_stratagem_entities.py: do not edit by hand.')
tail = re.sub(r'M\.SUBS=\{weapon=\{\}[^"\n]*\}', 'M.SUBS={stratagem={}}', tail)
tail = re.sub(r"open\(os\.environ\.get\('OUT',.*?\),'w'", "open(os.environ.get('OUT_STRATAGEM_ENTITIES',os.path.join(HERE,'..','..','offline','stratagem_entity_specs.lua')),'w'", tail)
exec(tail)
# Register all current keyed ECS tables. Only entities reached from the selected
# stratagem are materialized, and their fields are lazy until a component opens.
names = {}
for path in glob.glob(DUMP + '*.json'):
    name = os.path.basename(path)[:-5]; names[dh(name)] = name
raw_path = os.path.join(RAWDATA, 'Data', 'entity_deltas', 'entity_deltas_raw.json')
for entity in json.load(open(raw_path, encoding='utf-8'))['entities']:
    for entry in next(iter(entity.values()))['modified_components']:
        names[int(entry['type_hash_hex'], 16)] = entry['type_name']
roots = []
for kind in sorted(B):
    t = T.get(kind)
    if not t or len(t['members']) != 2: continue
    a, b = t['members']
    if a['atom'] != 2 or b['atom'] != 2 or a['size'] != a['count'] * 16 or b['type'] not in T: continue
    roots.append(' {0x%08X,%d,%s},' % (kind, T[b['type']]['size'], luastr(names.get(kind, 'Component_0x%08X' % kind))))
path = os.environ.get('OUT_STRATAGEM_ENTITIES', os.path.join(HERE,'..','..','offline','stratagem_entity_specs.lua'))
text = open(path, encoding='utf-8').read().replace('return M\n', 'M.ROOTS={\n'+'\n'.join(roots)+'\n}\nreturn M\n')
open(path, 'w', encoding='utf-8', newline='\n').write(text)
print('Registered keyed component kinds:', len(roots))
