"""Generate Health metadata from the installed typelib and hash-matched RawData.

COMPONENT_GEN_WORK contains entities.bin and typelib.bin; RAWDATA is the RawData
checkout. No game files are written. DamageableZoneInfo's RawData tail contains
two obsolete bools and calls two uint32s uint64: the current typelib wins.
"""
import json, os, re, runpy, struct, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.stdout.reconfigure(encoding='utf-8')
A = runpy.run_path(str(HERE / 'walk.py'))
T, dh, merged, walk = (A[k] for k in ('T', 'dh', 'merged', 'walk'))
RAW = Path(A['RAWDATA'])
text = (RAW / 'Data/entities/HealthComponentData.json').read_text(encoding='utf-8')
dump = json.loads(text)
samples = [next(iter(e.values())) for e in dump['entities']]
sample = next(v for v in samples if v['damageable_zones'])
info = json.loads(json.dumps(sample['damageable_zones'][0]['info']))
for key in ('unk_bool_r0x01BA', 'unk_bool_r0x01BB'):
    info.pop(key)
for suffix in ('01BC', '01C0'):
    info['unk_uint32_r0x' + suffix] = info.pop('unk_uint64_r0x' + suffix)
zone = {'info': info, 'actors': sample['damageable_zones'][0]['actors']}
sample = dict(sample, default_damageable_zone_info=info, damageable_zones=[zone] * 38)
row = T[dh('HealthComponentData')]['members'][1]['type']
zone_type = next(m['type'] for m in T[row]['members'] if m['offset'] == 520)
assert T[row]['size'] == 22096 and T[zone_type]['size'] == 552
warnings = []
fields = walk(row, sample, 0, '', [], None, warnings)
assert not warnings, warnings

# Chinese labels are explicit for every known leaf, including nested records.
ZH = {
 'health':'最大生命值', 'health_changerate':'普通生命变化速率（每秒）',
 'health_changerate_disabled':'禁用普通生命恢复', 'health_changerate_cooldown':'受伤后恢复冷却（秒）',
 'regeneration_segments':'分段恢复段数', 'regeneration_changerate':'分段恢复速率（每秒）',
 'constitution':'倒地／流血生命值', 'constitution_changerate':'倒地生命变化速率（每秒）',
 'constitution_disables_interactions':'倒地时禁用交互', 'zone_bleedout_changerate':'部位流血变化速率（每秒）',
 'unit_size':'单位体型', 'unit_mass':'单位质量', 'kill_score':'击杀分数',
 'sway_multiplier':'受伤晃动倍率', 'move_speed_multiplier':'受伤移动速度倍率',
 'on_dead_effect':'部位死亡特效', 'on_downed_effect':'部位倒地特效', 'zone_name':'部位名称 ID',
 'on_dead_script_event':'死亡脚本事件 ID', 'on_dead_animation_event':'死亡动画事件 ID',
 'on_dead_audio_event':'死亡音效 ID', 'on_dead_audio_event_node':'死亡音源节点 ID',
 'on_dead_hide_visibility_group':'死亡时隐藏的可见组 ID', 'on_dead_show_visibility_group':'死亡时显示的可见组 ID',
 'on_dead_hide_visibility_mask':'死亡时隐藏的可见遮罩', 'on_dead_show_visibility_mask':'死亡时显示的可见遮罩',
 'on_downed_hide_visibility_mask':'倒地时隐藏的可见遮罩', 'on_downed_show_visibility_mask':'倒地时显示的可见遮罩',
 'destroyed_assignment_event':'摧毁指派事件 ID', 'on_dead_locomotion_set':'死亡移动状态组 ID',
 'on_hit_script_event':'命中但未受伤时的脚本事件 ID', 'on_bleedout_script_event':'流血耗尽脚本事件 ID',
 'on_downed_script_event':'倒地脚本事件 ID', 'on_heal_script_event':'治疗脚本事件 ID',
 'on_downed_audio_event':'倒地音效 ID', 'on_downed_audio_event_node':'倒地音源节点 ID',
 'on_downed_locomotion_set':'倒地移动状态组 ID', 'on_damage_script_event':'受伤脚本事件 ID',
 'damage_multiplier':'直接伤害倍率档位', 'damage_multiplier_dps':'持续伤害倍率档位',
 'projectile_durable_resistance':'耐久伤害占比（0–1）', 'armor':'护甲等级',
 'armor_angle_check':'按入射角检查护甲', 'max_armor':'角度检查的最高护甲等级', 'ignore_armor_on_self':'忽略自身护甲减伤',
 'immortal':'本体存活时部位不死', 'causes_downed_on_downed':'部位倒地使本体倒地',
 'causes_death_on_downed':'部位倒地使本体死亡', 'causes_downed_on_death':'部位死亡使本体倒地',
 'causes_death_on_death':'部位死亡使本体死亡', 'affects_main_health':'传递到本体的伤害倍率',
 'child_zones':'子部位名称 ID', 'kill_children_on_death':'死亡时杀死子部位',
 'regeneration_enabled':'允许部位恢复', 'bleedout_enabled':'允许部位流血',
 'affected_by_explosions':'部位承受爆炸伤害', 'explosion_damage_multiplier':'爆炸伤害倍率',
 'on_dead_disable_all_actors':'部位死亡时禁用全部物理体', 'affected_by_collision_impact':'受碰撞冲击影响',
 'explosion_verification_mode':'爆炸射线验证模式', 'main_health_affect_capped_by_zone_health':'传递伤害上限为部位生命与倒地生命之和',
 'hit_effect_receiver_type':'受击特效接收类型', 'use_surface_effect':'使用表面特效',
 'health_event_triggers':'生命阈值事件', 'health_percent':'生命比例阈值', 'event_name':'低于阈值事件 ID', 'reverse_event_name':'恢复越过阈值事件 ID',
 'event_sound':'低于阈值音效 ID', 'reverse_event_sound':'恢复越过阈值音效 ID',
 'health_event_trigger_audio_node':'生命事件音源节点 ID', 'actors':'部位物理体名称 ID',
 'element_damage':'元素伤害', 'decay':'尸体消散', 'effect':'特效',
 'type':'元素类型', 'multiplier':'元素伤害倍率', 'mode':'尸体消散模式', 'acceleration':'消散加速度（米／秒²）',
 'min_delay':'最短消散延迟（秒）', 'max_delay':'最长消散延迟（秒）', 'death_sound_ids':'死亡音效 ID',
 'trigger_death_sounds_on_remove':'移除实体时播放死亡音效', 'on_hit_effect':'受伤特效',
 'while_living_effect':'存活特效', 'on_death_effect':'死亡特效', 'bled_to_death_effect':'流血死亡特效',
 'unk_effect':'未知特效', 'id':'特效名称 ID', 'start_enabled':'初始启用',
 'particle_effect':'粒子特效资源哈希', 'offset':'位置偏移', 'rotation_offset':'旋转偏移',
 'node_id':'挂点名称 ID', 'trigger_emit_event':'发射事件 ID', 'link_option':'脱离宿主时的处理',
 'inherit_rotatione':'继承旋转', 'linked':'跟随宿主', 'spawn_on_camera':'在相机处生成',
 'effect_unk_bit_4':'未知特效位 3', 'effect_unk_bit_5':'未知特效位 4',
 'require_demolition':'仅承受拆毁伤害', 'downed_anim':'倒地动画 ID', 'dead_anim':'死亡动画 ID',
 'on_downed_hide_visibility_group':'倒地时隐藏的可见组 ID', 'on_downed_show_visibility_group':'倒地时显示的可见组 ID',
 'on_death_destruction_level':'死亡时的拆毁等级', 'can_die_naturally':'允许自然死亡',
 'death_propagation':'死亡向父子实体传播', 'ui_health_strings':'生命 UI 文本 ID',
 'death_animation_sound':'死亡动画音效',
}
GROUPS = [
 ('body','Body health','本体生命与倒地'), ('regen','Regeneration','恢复与流血'),
 ('unit','Unit and wounded state','体型、击杀与受伤状态'),
 ('vitals','Zone health and death linkage','部位生命与倒地／死亡联动'),
 ('damage','Armor and damage','护甲与伤害'), ('children','Child zones','子部位联动'),
 ('actors','Physical actors','部位物理体'), ('zone_regen','Zone regeneration and bleed-out','部位恢复与流血'),
 ('blast','Explosions and collision','爆炸与碰撞'), ('triggers','Health threshold events','生命阈值事件'),
 ('events','Script and animation events','脚本、动画与移动事件'),
 ('visibility','Visibility','可见组与遮罩'), ('audio','Audio','音效与音源'),
 ('effects','Particle effects','粒子特效'), ('elements','Element damage','元素伤害'),
 ('decay','Corpse decay','尸体消散'), ('death','Entity death and demolition','实体死亡与拆毁'),
 ('ui','Health UI','生命界面'), ('unknown','Unknown fields','未知字段'),
]
body_ids = {0:'health',4:'regen',12:'regen_delay',24:'bleed',268:'durable',280:'armor',388:'explosive'}
zone_ids = {232:'health',216:'armor',204:'durable',324:'explosive',248:'to_body',244:'fatal'}

def category(p):
    tail = p.split('.')[-1]; name = re.sub(r'\[\d+\]', '', tail)
    if name.startswith('unk_') or name.startswith('effect_unk_'): return 'unknown'
    if 'effect' in p and name not in ('hit_effect_receiver_type','use_surface_effect'): return 'effects'
    if 'element_damage' in p: return 'elements'
    if p.startswith('decay.'): return 'decay'
    if 'health_event_triggers' in p: return 'triggers'
    if name=='health_event_trigger_audio_node': return 'triggers'
    if 'visibility' in name: return 'visibility'
    if 'sound' in p or 'audio' in name: return 'audio'
    if 'child' in name: return 'children'
    if name=='actors': return 'actors'
    if 'explos' in name or 'collision' in name: return 'blast'
    if any(t in name for t in ('armor','damage_multiplier','durable','hit_effect_receiver','use_surface')) or name in ('affects_main_health','main_health_affect_capped_by_zone_health'): return 'damage'
    if name in ('regeneration_enabled','bleedout_enabled'): return 'zone_regen'
    if name in ('health','constitution','zone_name','immortal') or name.startswith('causes_'): return 'vitals' if '.' in p else 'body'
    if p.startswith('wounded_state.') or name in ('unit_size','unit_mass','kill_score'): return 'unit'
    if any(t in name for t in ('changerate','regeneration','constitution_disables')): return 'regen'
    if any(t in name for t in ('script_event','animation_event','locomotion','assignment_event')): return 'events'
    if name in ('downed_anim','dead_anim','require_demolition','can_die_naturally','death_propagation','on_death_destruction_level','on_dead_disable_all_actors'): return 'death'
    if name=='ui_health_strings': return 'ui'
    raise AssertionError(('uncategorized',p))

def label(p):
    parts = []
    for seg in p.split('.'):
        if seg in ('info','default_damageable_zone_info','effect_flags','wounded_state'): continue
        m = re.fullmatch(r'(.*?)(?:\[(\d+)\])?',seg); n, ix = m.groups()
        if n.startswith('unk_'):
            off=re.search(r'0x([A-Fa-f\d]+)',n)
            typ='开关'if 'bool'in n else '浮点'if 'float'in n else '整数'if 'uint'in n else '事件'if 'event'in n else '数组'if 'array'in n else '字段'
            z='未知'+typ+(' +0x'+off[1]if off else '（'+n+'）')
        else:
            z = ZH.get(n)
            if n in ('x','y','z'): z=n.upper()
            assert z, (p,n)
        if ix is not None: z+=' '+str(int(ix)+1)
        parts.append(z)
    return ' · '.join(parts)

enums={}
for value, name, entry in re.findall(r'"(-?\d+) <=> ([A-Za-z0-9]+)_([A-Za-z0-9_]+)"',text):
    enums.setdefault(dh(name),{'name':name,'values':{}})['values'][int(value)]=entry
for tid,e in list(enums.items()):
    path=RAW/'Data/enums'/f'{e["name"]}.txt'
    if path.exists():
        for i,line in enumerate(path.read_text(encoding='utf-8').splitlines()):
            line=line.strip()
            if line: e['values'][i]=line.removeprefix(e['name']+'_')
ENUM_ZH={'Small':'小型','Medium':'中型','Large':'大型','Massive':'巨型','None':'无','none':'无',
 'Critical':'暴击','Normal':'普通','Reduced':'降低','Symbolic':'象征性伤害','OuterRadius':'外半径','All':'全部',
 'Fire':'火焰','Electricity':'电击','Acid':'酸液','Bleed':'流血','Gas':'毒气','illuminatePlasma':'光能等离子',
 'VehicleDamage':'载具伤害','Tornado':'龙卷风','Noxious':'毒素','Regular':'普通消散','Long':'长时间消散',
 'Instant':'立即消散','ToParent':'传播到父实体','ToChildren':'传播到子实体','Both':'双向传播',
 'Destroy':'销毁','Stop':'停止','Disconnect':'断开','SmallArms':'轻武器',
 'FragGrenade_HeavyMachinegun_Sniper_Car_Mech':'破片手雷／重机枪／狙击枪／车辆／机甲',
 'Autocannon_Charger_Recoilless_LAV':'机炮／冲锋虫／无后坐力炮／轻装甲车',
 'Strider_EagleRockets':'阔步者／飞鹰火箭','OrbitalBombardment':'轨道轰炸','Hellbomb':'地狱火炸弹',
 'ForceDestroyTrees':'强制毁树','ExplodingBarrel':'爆炸桶','Script':'脚本','Count':'数量标记','Num':'数量标记'}

# Native strict layout (merged packed bits occupy one byte, checked separately below).
def layout(tid):
    ls=[];ns={}
    for m in merged(tid):
        ls.append([m['offset'],m['size']] if m['bits'] is not None else [m['offset'],m['size'],m['storage'],m['atom'],m['count'],m['type']])
        if m['storage']==20:
            sub,inner=layout(m['type']);ns[m['offset']]={'size':T[m['type']]['size'],'required':True,'layout':sub,'nested':inner}
    return ls,ns

def lua(v):
    if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
    if isinstance(v,bool): return 'true'if v else'false'
    if isinstance(v,(int,float)): return str(v)
    if isinstance(v,(tuple,list)): return '{'+','.join(lua(x)for x in v)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x)for k,x in v.items())+'}'

def metadata(f):
    p,st,off=f['path'],f['st'],f['off'];x={}
    if st=='u8': st='flag' # checked across all records, including inactive slots, below
    if st=='enum':
        e=enums.get(f['enum'])
        if e: x.update(enum='e%08X'%f['enum'],enum_type=e['name'])
        if f.get('signed_enum'): st='i32'
    rng= 'flag'if st.startswith('bit')or st=='flag'else 'u8'if st=='u8'else 'signed'if st=='i32'else 'hash'if st in ('enum','u32','u64')else 'scalar'
    if st=='f32':
        if 'health_percent'in p or 'durable'in p: rng='ratio'
        elif 'multiplier'in p or 'affects_main_health'in p: rng='mult'
        elif any(n in p for n in ('cooldown','delay')): rng='time'
    prefix=''
    zm=re.match(r'damageable_zones\[(\d+)\]\.(.*)',p)
    if zm:
        z=int(zm[1]);rel=off-520-z*552;prefix='zone'+str(z)+'_';alias=zone_ids.get(rel)
    else: alias=body_ids.get(off)
    x['id']=prefix+alias if alias else re.sub(r'[^a-zA-Z0-9_]','_',p)
    if st=='u64': x['entity']=False
    if 'damage_multiplier' in p and 'explosion'not in p:
        x['note']=['This is a DamageMultiplier enum, not a floating-point multiplier.','这是 DamageMultiplier 枚举档位，不是直接填写的小数倍率。','这是 DamageMultiplier 枚举档位，不是直接填写的小数倍率。']
    if p.endswith(('unk_uint32_r0x01BC','unk_uint32_r0x01C0')):
        x['note']=['The current type library defines this as uint32; RawData calls it uint64.','当前类型库确认这里是 uint32；RawData 中的 uint64 名称不代表实际写入宽度。','当前类型库确认这里是 uint32；RawData 中的 uint64 名称不代表实际写入宽度。']
    return [p,off,st,category(p),p.replace('_',' '),label(p),label(p),rng,x]

# Verify storage/data and expose non-boolean byte fields without a boolean clamp.
records,_=A['keyed'](T,dh('HealthComponentData'))
native_leaves={(off,bit):storage for off,size,storage,bit in A['leaves'](row)}
for f in fields:
    if f['st']=='enum'and native_leaves[(f['off'],None)]==12: f['signed_enum']=True
    if f['st']=='u8'and any(A['E'][at+f['off']]not in (0,1)for at in records.values()): f['st']='byte'
root_fields=[metadata(f)for f in fields if not f['path'].startswith('damageable_zones[')]
zone_fields=[]
for f in fields:
    if f['path'].startswith('damageable_zones[0].'):
        f=dict(f,path=f['path'].removeprefix('damageable_zones[0].'),off=f['off']-520)
        item=metadata(f);item[8]['id']=zone_ids.get(f['off'])or re.sub(r'[^a-zA-Z0-9_]','_',f['path'])
        zone_fields.append(item)
assert not any(f[2]=='byte'for f in root_fields+zone_fields),'non-boolean byte: add explicit u8 support'
# Validate RawData naming by comparing all matching records, matching compacted zones by zone_name.
fmt={'i32':'i','f32':'f','u32':'I','u64':'Q','enum':'I','u8':'B'}
def raw_value(v,path):
    for part in re.findall(r'[^.\[\]]+|\[\d+\]',path):
        v=v[int(part[1:-1])]if part.startswith('[')else v[part]
    return int(v.split()[0])if isinstance(v,str)else v
compared=0;differences={}
for ent in dump['entities']:
    h,v=next(iter(ent.items()));at=records.get(h.removeprefix('0x').upper())
    if at is None: continue
    for f in fields:
        p=f['path'];base=at
        zm=re.match(r'damageable_zones\[(\d+)\]\.(.*)',p)
        obj=v;path=p
        if zm:
            z=int(zm[1]);zone_id=struct.unpack_from('<I',A['E'],at+520+z*552+96)[0]
            if not zone_id: continue
            matches=[x for x in v['damageable_zones']if x['info']['zone_name']==zone_id]
            if len(matches)!=1: continue
            obj,path=matches[0],zm[2]
        # The two erroneous dump-only bools are not in fields. Their neighboring words have legacy names.
        path=path.replace('unk_uint32_r0x01BC','unk_uint64_r0x01BC').replace('unk_uint32_r0x01C0','unk_uint64_r0x01C0')
        if f['st'].startswith('bit'):
            head,key=path.rsplit('.',1);head=head.replace('effect_flags','effect_flags_detail');path=head+'.'+key
        try: value=raw_value(obj,path)
        except (KeyError,IndexError): continue
        actual=(A['E'][at+f['off']]>>int(f['st'][3:]))&1 if f['st'].startswith('bit') else struct.unpack_from('<'+fmt[f['st']],A['E'],at+f['off'])[0]
        compared+=1
        if abs(actual-value)>1e-5*max(1,abs(value)):
            differences.setdefault(p,[]).append((h,actual,value))
print('RawData comparisons',compared,'differing field paths',len(differences))
if differences:
    print('differences',[(p,len(v),v[:1])for p,v in differences.items()][:12])
    # Versioned values may differ. A named root/zone tail with widespread differences is a schema failure.
    assert all(len(v)<30 for v in differences.values()),'RawData alignment differs across many entities'

l,n=layout(row)
lines=['-- Generated by tools/component_gen/gen_health.py; native layout wins over dump names.',
       '-- Field names, types and offsets: Darctor/Helldivers2_RawData (https://github.com/Darctor/Helldivers2_RawData), aligned to the installed typelib.',
       "local V=require('component_view')",'local S={TYPE="HealthComponentData",KEY="health",HASH='+str(dh('HealthComponentData'))+',SIZE=22096,SLOT="HealthComponents",FLAG="health_component",STRICT=true,OPEN_ENUMS=true,COMPONENT={"Health component","生命组件","生命组件"}}',
       'S.LAYOUT='+lua(l),'S.NESTED='+lua(n),'S.GROUPS='+lua([[g,e,z,z]for g,e,z in GROUPS]),
       'S.RANGES={signed={-2147483648,2147483647,10,100,true},scalar={-1e9,1e9,.1,1,true},hash={0,4294967295,1,1},flag={0,1,1,1},ratio={0,1,.05,.1},mult={0,100,.05,.25},time={-1,3600,.1,1,true}}',
       'S.ENUMS='+lua({'e%08X'%tid:{v:[en,ENUM_ZH.get(en,en),ENUM_ZH.get(en,en)]for v,en in e['values'].items()}for tid,e in enums.items()}),
       'S.ROOT='+lua(root_fields),'S.ZONE='+lua(zone_fields),
       'local F={};local function add(s,prefix,base,bucket,group_prefix)',
       'local x={};for k,v in pairs(s[9])do x[k]=v end;x.id=prefix..x.id;x.bucket=bucket',
       'local path=s[1];if bucket:match("^zone%d+$")then path="damageable_zones["..bucket:match("%d+").."]."..path end',
       'F[#F+1]={path,base+s[2],s[3],group_prefix..s[4],s[5],s[6],s[7],S.RANGES[s[8]],x}',
       'end',
       'local groups={};for _,g in ipairs(S.GROUPS)do groups[#groups+1]=g end',
       'for _,s in ipairs(S.ROOT)do add(s,"",0,s[1]:match("^default_damageable_zone_info%.")and"default"or s[4],"")end',
       'for z=0,37 do local key="zone"..z;for _,g in ipairs(groups)do S.GROUPS[#S.GROUPS+1]={key..":"..g[1],g[2],g[3],g[4]}end',
       'for _,s in ipairs(S.ZONE)do add(s,key.."_",520+z*552,key,key..":")end end',
       'S.FIELDS=F;return V.prepare(S)']
out=HERE.parents[1]/'offline/health_schema.lua'
out.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Generated',len(root_fields),'root/default fields + 38 ×',len(zone_fields),'zone fields =',len(fields),'native leaves')
