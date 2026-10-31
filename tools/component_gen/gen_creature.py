"""Full creature component specs, using the installed layout and the shared value/name alignment."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
source = open(os.path.join(HERE, 'gen.py'), encoding='utf-8').read()
head, tail = source.split("L=['-- GENERATED", 1)
head = head.replace("    ids=[f['x']['id'] for f in fl]; assert len(ids)==len(set(ids)),comp", """    seen=set()
    for f in fl:
        base=f['x']['id']
        if base in seen:
            f['x']['id']=base+'_at_%04X'%f['off']
            while f['x']['id'] in seen: f['x']['id']+='_'+f['st']
        seen.add(f['x']['id'])""")
exec(head)
# Inline fields are editable; pointer/dynamic-array descriptors must not become integer edits.
walk_source = open(os.path.join(HERE, 'walk.py'), encoding='utf-8').read()
walk_source = walk_source[walk_source.index('def walk('):walk_source.index('def fields(')]
walk_source = walk_source.replace("        name=ks[i] if ks else None", "        if m['atom']==1 or m['storage'] not in (2,4,6,7,8,12,14,16,17,20): continue\n        name=ks[i] if ks else None")
exec(walk_source)
COMP_INFO = {
 'UnitComponentData': ('creature_unit', '单位', '單位', 'Unit'),
 'HitReactComponentData': ('hit_react', '硬直反应', '硬直反應', 'Hit reactions'),
 'StatusEffectReceiverComponentData': ('status_receiver', '状态接收', '狀態接收', 'Status receiver'),
 'LocomotionComponentData': ('locomotion', '移动运动', '移動運動', 'Locomotion'),
 'RotationComponentData': ('rotation', '转向旋转', '轉向旋轉', 'Rotation'),
 'MeleeAttackComponentData': ('melee_attack', '近战攻击', '近戰攻擊', 'Melee attack'),
 'DamageZoneShieldComponentData': ('damage_zone_shield', '部位护盾', '部位護盾', 'Zone shield'),
 'StatusEffectVolumeComponentData': ('status_volume', '状态区域', '狀態區域', 'Status volume'),
 'UnitCustomizationComponentData': ('unit_customization', '单位自定义', '單位自訂', 'Unit customization'),
 'CharacterVoiceComponentData': ('character_voice', '角色语音', '角色語音', 'Character voice'),
}
SUBOF = {name: 'creature' for name in COMP_INFO}
tail = "L=['-- GENERATED" + tail
tail = tail.replace('tools/component_gen/gen.py: do not edit by hand.', 'tools/component_gen/gen_creature.py: do not edit by hand.')
tail = tail.replace('Every weapon component', 'Every creature component')
tail = tail.replace("    L.append(' S.FIELDS=F')", "    if comp in ('LocomotionComponentData', 'RotationComponentData'): L.append(' S.SLACK=4 -- keyed record array trailing alignment')\n    L.append(' S.FIELDS=F')")
tail = re.sub(r'M\.SUBS=\{weapon=\{\}[^"\n]*\}', 'M.SUBS={creature={}}', tail)
tail = re.sub(r"open\(os\.environ\.get\('OUT',.*?\),'w'", "open(os.environ.get('OUT_CREATURE',os.path.join(HERE,'..','..','offline','creature_component_specs.lua')),'w'", tail)
exec(tail)
