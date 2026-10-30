import os
HERE=os.path.dirname(os.path.abspath(__file__))
# Generates offline/weapon_components.lua: every weapon component's full layout (type library) with names from the
# RawData dump (aligned by value across all entities), labels from zh.py, enum names, and the nested layout checks.
exec(open(os.path.join(HERE,'build_names.py')).read().split("if __name__=='__main__':")[0])
exec(open(os.path.join(HERE,'zh.py')).read())
import glob
ENUMDIR=os.path.join(RAWDATA,'Data','enums')+os.sep
# enum names: the enum files, then the dumps' "N <=> Type_Value" strings
ENUM={}
for p in glob.glob(ENUMDIR+'*.txt'):
    n=os.path.basename(p)[:-4]; vals={}
    for i,l in enumerate(open(p,encoding='utf-8').read().split('\n')):
        l=l.strip()
        if not l: continue
        m=re.match(r'^(-?\d+):(\S+)$',l)
        v,name=(int(m.group(1)),m.group(2)) if m else (i,l)
        vals[v]=name
    ENUM[dh(n)]=(n,vals)
def dump_enums():
    for f in glob.glob(DUMP+'*.json'):
        for m in re.finditer(r'"(-?\d+) <=> ([A-Za-z0-9]+)_([A-Za-z0-9_]+)"',open(f,encoding='utf-8').read()):
            v,t,name=int(m.group(1)),m.group(2),m.group(3)
            if t.startswith('0x'): continue
            e=ENUM.setdefault(dh(t),(t,{}))
            e[1].setdefault(v,t+'_'+name)
dump_enums()
exec(open(os.path.join(HERE,'shal.py')).read())
ENUM_TYPE_NAME=dict(EH)
ENUM_TYPE_NAME[0xE67629CC]='WeaponScreenType'   # (dh('WeaponScreenType') == the type library's hash: found by trying names)
for h,(n,_) in ENUM.items(): ENUM_TYPE_NAME[h]=n
REFS={dh('ProjectileType'):'projectile_id',dh('ExplosionType'):'explosion_id',dh('DamageInfoType'):'damage_id',
      dh('StatusEffectType'):'status_effect_id',dh('ArcType'):'arc_id',dh('BeamType'):'beam_id'}
COMP_INFO={ # key, slot, sub, 简体, 繁體, English
'WeaponDataComponentData':('weapon_data','武器数据','武器數據','Weapon data'),
'WeaponReloadComponentData':('weapon_reload','装填','裝填','Reload'),
'WeaponMagazineComponentData':('weapon_magazine','弹匣','彈匣','Magazine'),
'WeaponChargeComponentData':('weapon_charge','蓄力','蓄力','Charge'),
'WeaponRoundsComponentData':('weapon_rounds','弹药','彈藥','Rounds'),
'WeaponHeatComponentData':('weapon_heat','热量','熱量','Heat'),
'WeaponWindUpComponentData':('weapon_windup','预热','預熱','Wind-up'),
'WeaponAssistedReloadComponentData':('weapon_assisted_reload','协助装填','協助裝填','Assisted reload'),
'ProjectileWeaponComponentData':('projectile_weapon','射弹武器','射彈武器','Projectile weapon'),
'SprayWeaponComponentData':('spray_weapon','喷射武器','噴射武器','Spray weapon'),
'ArcWeaponComponentData':('arc_weapon','电弧武器','電弧武器','Arc weapon'),
'BeamWeaponComponentData':('beam_weapon','光束武器','光束武器','Beam weapon'),
'MeleeWeaponComponentData':('melee_weapon','近战武器','近戰武器','Melee weapon'),
'AbilityWeaponComponentData':('ability_weapon','技能武器','技能武器','Ability weapon'),
'GuidedWeaponComponentData':('guided_weapon','制导武器','制導武器','Guided weapon'),
'PhysicsWeaponComponentData':('physics_weapon','物理武器','物理武器','Physics weapon'),
'MountedWeaponComponentData':('mounted_weapon','架设武器','架設武器','Mounted weapon'),
'WeaponCustomizationComponentData':('weapon_customization','武器自定义','武器自訂','Customization'),
'WeaponAttachmentComponentData':('weapon_attachment','配件','配件','Attachment'),
'WeaponFlashlightComponentData':('weapon_flashlight','手电','手電','Flashlight'),
'WeaponLaserComponentData':('weapon_laser','激光指示器','雷射指示器','Laser'),
'WeaponScreenComponentData':('weapon_screen','屏幕','螢幕','Screen'),
'WeaponLinkedAmmoComponentData':('weapon_linked_ammo','连接弹药','連接彈藥','Linked ammo'),
'WeaponLinkerComponentData':('weapon_linker','连接器','連接器','Linker'),
'WeaponWielderComponentData':('weapon_wielder','持握者','持握者','Wielder'),
'EquipmentComponentData':('equipment','装备','裝備','Equipment'),
'InteractableComponentData':('interactable','交互','互動','Interactable'),
}
SUBOF={}
for c in ['WeaponDataComponentData','WeaponReloadComponentData','WeaponMagazineComponentData','WeaponChargeComponentData','WeaponRoundsComponentData','WeaponHeatComponentData','WeaponWindUpComponentData','WeaponAssistedReloadComponentData']: SUBOF[c]='weapon'
for c in ['ProjectileWeaponComponentData','SprayWeaponComponentData','ArcWeaponComponentData','BeamWeaponComponentData','MeleeWeaponComponentData','AbilityWeaponComponentData','GuidedWeaponComponentData','PhysicsWeaponComponentData','MountedWeaponComponentData']: SUBOF[c]='type'
for c in ['WeaponCustomizationComponentData','WeaponAttachmentComponentData','WeaponFlashlightComponentData','WeaponLaserComponentData','WeaponScreenComponentData','WeaponLinkedAmmoComponentData','WeaponLinkerComponentData','WeaponWielderComponentData']: SUBOF[c]='attach'
# 实体组件 › 挂载: how a weapon is carried and picked up (with the mounts and the backpack's inventory)
for c in ['EquipmentComponentData','InteractableComponentData']: SUBOF[c]='mount'
UNKRE=re.compile(r'^unk_([a-z0-9]+?)_(?:(r)?0x([0-9A-Fa-f]{4}))$')
def seg_label(seg,absoff=None):
    m=re.match(r'^(.*?)\[(\d+)\]$',seg); idx=None
    if m: seg,idx=m.group(1),int(m.group(2))
    u=UNKRE.match(seg)
    if u:
        t=UNKT.get(u.group(1),(u.group(1),u.group(1)))
        off=int(u.group(3),16)
        en='Unknown %s +0x%X'%(u.group(1),off); zs=('未知%s +0x%X'%(t[0],off),'未知%s +0x%X'%(t[1],off))
    elif re.match(r'^0x[0-9A-F]{8}$',seg):
        en='Unnamed struct '+seg; zs=('未命名结构 '+seg,'未命名結構 '+seg)
    else:
        en=seg.replace('_',' '); zs=words(seg)
    if idx is not None:
        en+=' %d'%(idx+1); zs=(zs[0]+' %d'%(idx+1),zs[1]+' %d'%(idx+1))
    return en,zs[0],zs[1]
def luastr(s): return "'"+s.replace('\\','\\\\').replace("'","\\'")+"'"
def range_of(path,st,vals):
    n=path.lower()
    if st.startswith('bit') or st=='flag': return 'flag'
    if st=='u8': return 'u8'
    if st in('enum','enum8'): return 'enum'
    if st=='u64': return 'hash'
    if st=='i32': return 'i32'
    if st=='u32':
        if re.search(r'node|event|hash|path|sound|audio|anim|effect|variable|rtpc|vo|icon|id\b|_id|crosshair|unit|material|template',n): return 'hash'
        return 'count'
    if re.search(r'time|delay|duration|timer|cooldown|interval',n): return 'ssec'
    if re.search(r'multiplier|scale|ratio|percentage|modifier',n): return 'mult'
    if re.search(r'angle|degree|rotation|yaw|pitch',n): return 'deg'
    return 'raw'
# names the editor already knew for components the dump does not have
MANUAL={'WeaponWindUpComponentData':{0:'wind_up_time',4:'wind_down_time'}}
SEEN=('Meaning inferred from the entities that use each value; not a name from the game.','含义按各实体所用数值推断，不是游戏里的名称。','含義按各實體所用數值推斷，不是遊戲裡的名稱。')
OVERRIDE={
 'GuidedWeaponComponentData':{0:dict(en='Guidance role (inferred)',zhs='制导角色（推断）',zht='制導角色（推斷）',enum='gGuided',
   values={0:('Value 0 (unused)','值 0（无实体使用）','值 0（無實體使用）'),1:('Missile (TD-110 Maelstrom missile)','导弹（TD-110 风暴漩涡 垂发火箭射弹）','導彈（TD-110 風暴漩渦 垂發火箭射彈）'),
           2:('Launcher (TD-110 Maelstrom launcher)','发射器（TD-110 风暴漩涡 垂发火箭）','發射器（TD-110 風暴漩渦 垂發火箭）'),
           3:('Designator (TD-110 Maelstrom target designator)','指示器（TD-110 风暴漩涡 激光指示器）','指示器（TD-110 風暴漩渦 激光指示器）')},
   note=('The game has 3 records: the Maelstrom missile = 1, launcher = 2, target designator = 3 (enum 0x08DE3ACE, 4 values, name not public). '+SEEN[0],
         '游戏里共 3 条记录：风暴漩涡导弹 = 1、发射器 = 2、激光指示器 = 3（枚举 0x08DE3ACE，共 4 个值，名称未公开）。'+SEEN[1],
         '遊戲裡共 3 條記錄：風暴漩渦導彈 = 1、發射器 = 2、激光指示器 = 3（列舉 0x08DE3ACE，共 4 個值，名稱未公開）。'+SEEN[2]))},
 'WeaponScreenComponentData':{0:dict(en='Screen type',zhs='屏幕类型',zht='螢幕類型',enum='gScreen',
   values={0:('Type 0 (MA5C assault rifle)','类型 0（MA5C 突击步枪所用）','類型 0（MA5C 突擊步槍所用）'),1:('Type 1 (P-33 missile pistol)','类型 1（P-33 制导手枪所用）','類型 1（P-33 制導手槍所用）'),
           2:('Type 2 (unused)','类型 2（无实体使用）','類型 2（無實體使用）')},
   note=('Enum WeaponScreenType (3 values): the MA5C assault rifle uses 0, the P-33 missile pistol 1. '+SEEN[0],
         '枚举 WeaponScreenType（3 个值）：MA5C 突击步枪用 0，P-33 制导手枪用 1。'+SEEN[1],
         '列舉 WeaponScreenType（3 個值）：MA5C 突擊步槍用 0，P-33 制導手槍用 1。'+SEEN[2]))},
 'MountedWeaponComponentData':{0:dict(note=('Only the TD-110 Maelstrom launcher has this component, with 0 here; no public source names it.',
   '只有 TD-110 风暴漩涡 垂发火箭带有此组件，此处为 0；公开资料中没有它的名称。','只有 TD-110 風暴漩渦 垂發火箭帶有此組件，此處為 0；公開資料中沒有它的名稱。'))},
}
CUSTOM_ENUMS={}
def gen(comp):
    key,zhs,zht,en=COMP_INFO[comp]
    out,res,_,_=named(comp)
    for i,f in enumerate(out):
        if i not in res and f['path'].count('.')==0 and f['off'] in MANUAL.get(comp,{}): res[i]=MANUAL[comp][f['off']]
    # the 2024 schemas: names where the dump has none, descriptions where both name the field alike
    SL=shal_leaves(T[dh(comp)]['members'][1]['type'])
    desc,inferred,shal_named={},set(),set()
    last=lambda p:re.sub(r'\[\d+\]','',p.split('.')[-1])
    used={res.get(i,f['path']) for i,f in enumerate(out)}
    for i,f in enumerate(out):
        bit=int(f['st'][3:]) if f['st'].startswith('bit') else None
        sl=SL.get((f['off'],bit))
        if not sl: continue
        cur=res.get(i,f['path'])
        if not UNK.match(last(cur)) and not re.match(r'^0x[0-9A-F]{8}$',last(cur)):
            if last(cur)==last(sl[0]) and sl[1]: desc[i]=sl[1]
        else:
            sp,cp=sl[0].split('.'),cur.split('.')
            if len(sp)==len(cp):   # (keep the dump's names where it has them)
                sp=[c if not UNK.match(re.sub(r'\[\d+\]$','',c)) else (x if '?' not in x else c) for x,c in zip(sp,cp)]
            elif '?' in sl[0]: continue
            np='.'.join(sp)
            if np==cur or np in used: continue   # (a name another field already has: the struct changed since)
            used.add(np); res[i]=np; shal_named.add(i)
            if sl[1]: desc[i]=sl[1]
            if not sl[2]: inferred.add(i)
    tid=dh(comp); rec,_=keyed(T,tid); row=T[tid]['members'][1]['type']
    # u8: switch when every record holds 0 / 1
    for f in out:
        if f['st']=='u8':
            vs={E[a+f['off']] for a in rec.values()}
            f['st']='flag' if vs<= {0,1} else 'u8'
    groups=[]; gidx={}
    fl=[]
    for i,f in enumerate(out):
        path=res.get(i,f['path'])
        segs=path.split('.')
        top=segs[0]
        is_scalar_top=len(segs)==1 or (len(segs)==2 and f['st'].startswith('bit') and False)
        gk='basic' if (len(segs)==1 and not re.search(r'\[\d+\]$',top)) else re.sub(r'\[\d+\]$','',top)
        if gk not in gidx:
            gidx[gk]=len(groups)
            if gk=='basic': groups.append((gk,'General','常规参数','常規參數'))
            else:
                e,a,b=seg_label(gk); groups.append((gk,e[:1].upper()+e[1:],a,b))
        rest=segs if gk=='basic' else ([re.sub(r'^.*?(\[\d+\])$',r'\1',top)] if re.search(r'\[\d+\]$',top) else [])+segs[1:]
        if rest and rest[0].startswith('['): rest[0]='#'+str(int(rest[0][1:-1])+1)
        parts=[]
        for s in rest:
            if s.startswith('#'): parts.append((s,s,s)); continue
            parts.append(seg_label(s))
        if not parts: parts=[seg_label(top)]
        ee=' · '.join(p[0] for p in parts); a=' · '.join(p[1] for p in parts); b=' · '.join(p[2] for p in parts)
        if f.get('enum') and UNKRE.match(re.sub(r'\[\d+\]$','',segs[-1])) and f['enum'] in ENUM_TYPE_NAME:
            tn=ENUM_TYPE_NAME[f['enum']]; ee+=' ('+tn+')'; a+='（'+tn+'）'; b+='（'+tn+'）'
        ee=ee[:1].upper()+ee[1:]
        x={'id':re.sub(r'[^A-Za-z0-9_]','_',path)}
        if i in desc: x['desc']=desc[i]
        if i in shal_named: x['shal']=True
        ov=OVERRIDE.get(comp,{}).get(f['off']) if '.' not in path else None
        if ov:
            if 'en' in ov: ee,a,b=ov['en'],ov['zhs'],ov['zht']
            if 'note' in ov: x['note']=ov['note']
            if 'enum' in ov: x['enum']=ov['enum']; CUSTOM_ENUMS[ov['enum']]=ov['values']
        if i in inferred: x['inferred']=True
        if f.get('enum'):
            e=ENUM.get(f['enum'])
            if f['enum'] in REFS: x['ref']=REFS[f['enum']]
            if e and any(not re.search(r'_Unknown_\d+$|^Unknown_\d+$',nm) for nm in e[1].values()): x['enum']='e%08X'%f['enum']; x['enum_type']=e[0]
            elif e: x['enum_type']=e[0]
            elif f['enum'] in ENUM_TYPE_NAME: x['enum_type']=ENUM_TYPE_NAME[f['enum']]
        fl.append(dict(path=path,off=f['off'],st=('enum' if f['st']=='enum8' else f['st']),st8=f['st']=='enum8',group=gk,en=ee,zhs=a,zht=b,rng=('u8' if f['st']=='enum8' else ('hash' if f['st']=='u32' and re.match(r'^\((Wwise sound|hashed name|unit resource|particle effect)\)',x.get('desc') or '') else range_of(path,f['st'],None))),x=x))
    ids=[f['x']['id'] for f in fl]; assert len(ids)==len(set(ids)),comp
    return key,zhs,zht,en,groups,fl,row
def layout_lua(tid,ind=''):
    ms=merged(tid); lay=[]; nest=[]
    for m in ms:
        lay.append('{%d,%d}'%(m['offset'],1 if m['bits'] is not None else m['size']))
        if m['storage']==20 and m['type'] in T:
            l,n=layout_lua(m['type'],ind+' ')
            nest.append('[%d]={size=%d,required=true,layout=%s%s}'%(m['offset'],T[m['type']]['size'],l,(',nested='+n) if n!='{}' else ''))
    return '{'+','.join(lay)+'}','{'+','.join(nest)+'}'
ORBITAL='--orbital' in sys.argv
if ORBITAL:
    COMP_INFO={'OrbitalAbilityComponentData':('orbital','轨道武器','軌道武器','Orbital weapon')}
    SUBOF={'OrbitalAbilityComponentData':'orbital'}
    ORBITAL_GROUPS=[('basic','Timing and tracking','持续时间与追踪','持續時間與追蹤'),
        ('damage','Damage zone','伤害区域','傷害區域'),('projectile','Projectile spawning','射弹生成','射彈生成'),
        ('effects','Effects and audio','特效与音效','特效與音效'),('factions','Target faction filters','目标阵营过滤','目標陣營過濾'),
        ('pattern','Movement pattern','移动轨迹','移動軌跡'),('points','Pattern control points (56 × XY)','轨迹控制点（56 × XY）','軌跡控制點（56 × XY）')]
    ORBITAL_LABELS={
        'pattern_segments':('Pattern segment count','轨迹段数','軌跡段數'),
        'smooth_segments':('Smooth segments','轨迹段平滑插值','軌跡段平滑插值'),
        'segment_pause':('Segment pause (s)','轨迹段停顿（秒）','軌跡段停頓（秒）'),
        'duration':('Damage duration (s)','伤害持续时间（秒）','傷害持續時間（秒）'),
        'remove_time':('Removal delay after completion (s)','结束后实体移除延迟（秒）','結束後實體移除延遲（秒）'),
        'movement_speed':('Tracking movement speed (m/s)','追踪移动速度（米/秒）','追蹤移動速度（米/秒）'),
        'search_radius':('Target search radius (m)','目标搜索半径（米）','目標搜尋半徑（米）'),
        'target_list_update_time':('Target list update interval (s; 0 disables)','目标列表刷新间隔（秒，0 禁用）','目標清單更新間隔（秒，0 停用）'),
        'damage_dealer_zone.damage_info_type':('Damage ID','伤害 ID','傷害 ID'),
        'damage_dealer_zone.interval':('Damage tick interval (s)','伤害判定间隔（秒）','傷害判定間隔（秒）'),
        'damage_dealer_zone.shape':('Damage zone shape','伤害区域形状','傷害區域形狀'),
        'damage_dealer_zone.gib_corpses':('Gib corpses','碎解尸体','碎解屍體'),
        'surface_impact':('Surface impact type','地表命中特效类型','地表命中特效類型'),
        'noise_hit_template':('Ground impact noise template','地面命中噪音模板','地面命中噪音範本'),
        'ship_effect':('Ship-to-target effect resource hash','舰船到目标特效资源哈希','艦船到目標特效資源雜湊'),
        'ship_effect_is_laser_pointer':('Ship effect acts as laser pointer','舰船特效作为激光指示器','艦船特效作為雷射指示器'),
        'audio_event_start':('Start audio event hash','启动音效事件哈希','啟動音效事件雜湊'),
        'audio_event_stop':('Stop audio event hash','停止音效事件哈希','停止音效事件雜湊'),
        'projectile_type':('Projectile ID','射弹 ID','射彈 ID'),
        'projectile_spawn_height':('Projectile spawn height (m)','射弹生成高度（米）','射彈生成高度（米）'),
        'projectile_spawn_delay':('Projectile spawn delay (s)','射弹生成延迟（秒）','射彈生成延遲（秒）'),
    }
    ORBITAL_ALIASES={'duration':'beam_duration','movement_speed':'beam_speed','search_radius':'beam_radius','damage_dealer_zone.interval':'beam_tick'}
    CUSTOM_ENUMS['eF892DF79']={0:('Sphere','球体','球體'),1:('Box','盒体','盒體'),2:('Capsule','胶囊体','膠囊體')}
    CUSTOM_ENUMS['eA23E9B46']={0:('None','无','無'),1:('Super Earth','超级地球','超級地球'),2:('Bugs','虫族','蟲族'),
        4:('Illuminate','光能者','光能者'),8:('Cyborg / Automatons','生化人／机器人','生化人／機器人'),16:('Wildlife','野生生物','野生生物'),32:('Citizens','平民','平民')}

L=['-- GENERATED by tools/component_gen/gen.py: do not edit by hand.','-- Every weapon component\'s full record: layout from the game\'s type library, names from Darctor/Helldivers2_RawData (https://github.com/Darctor/Helldivers2_RawData, 1.007.200)',
   '-- matched to the type library by value across every entity; names the dump lacks and English descriptions from',
   '-- shalzuth/HelldiversData (2024), paired by member type order; labels from tools/component_gen/zh.py.',
   "local V=require('component_view')","local R=V.R","local M={SPECS={},ENUMS={}}",
   "R.mult=R.mult or{-1e9,1e9,.05,.25,true}","R.count=R.count","R.i32=R.i32"]
used_enums=set()
for comp in COMP_INFO:
    key,zhs,zht,en,groups,fl,row=gen(comp)
    if ORBITAL:
        groups=ORBITAL_GROUPS
        for f in fl:
            p=f['path']
            f['group']='points' if p.startswith('pattern_control_points') else 'pattern' if p in ('pattern_segments','smooth_segments','segment_pause') else 'damage' if p.startswith('damage_dealer_zone') else 'projectile' if p.startswith('projectile_') else 'factions' if p.startswith('factions[') else 'effects' if p in ('surface_impact','noise_hit_template','ship_effect','ship_effect_is_laser_pointer','audio_event_start','audio_event_stop') else 'basic'
            if p in ORBITAL_LABELS: f['en'],f['zhs'],f['zht']=ORBITAL_LABELS[p]
            if p.startswith('damage_dealer_zone.size.'):
                axis=p[-1].upper();f['en'],f['zhs'],f['zht']='Damage zone size '+axis,'伤害区域尺寸 '+axis,'傷害區域尺寸 '+axis
            if f['group']=='factions':
                n=int(re.search(r'\[(\d+)\]',p).group(1))+1
                f['en'],f['zhs'],f['zht']='Target faction '+str(n),'目标阵营 '+str(n),'目標陣營 '+str(n)
            if p in ORBITAL_ALIASES: f['x']['id']=ORBITAL_ALIASES[p]
            if p=='damage_dealer_zone.interval': f['rng']='sec'
    tid=dh(comp)
    L.append('do')
    L.append(" local S={TYPE=%s,KEY=%s,SIZE=%d,HASH=0x%08X,SLOT=%s,FLAG=%s,COMPONENT={%s,%s,%s},GROUPS={"%(luastr(comp),luastr(key),T[row]['size'],tid,luastr(''.join(w.capitalize() for w in key.split('_'))+'Components'),luastr(key+'_component'),luastr(en+' component'),luastr(zhs+'组件（'+comp.replace('ComponentData','')+'）'),luastr(zht+'組件（'+comp.replace('ComponentData','')+'）')))
    for g in groups: L.append('  {%s,%s,%s,%s},'%tuple(luastr(x) for x in g))
    L.append(' }}')
    L.append(' S.ENUMS=M.ENUMS;S.OPEN_ENUMS=true   -- (enum names from the dump may be partial: no clamp to the named values)')
    L.append(' local F={}')
    for f in fl:
        x=f['x']; xs=['id='+luastr(x['id'])]
        if 'enum' in x:
            xs.append('enum='+luastr(x['enum']))
            if x['enum'] not in CUSTOM_ENUMS: used_enums.add(x['enum'])
        if 'enum_type' in x: xs.append('enum_type='+luastr(x['enum_type']))
        if 'ref' in x: xs.append('ref='+luastr(x['ref']))
        if 'desc' in x: xs.append('desc='+luastr(x['desc']))
        if x.get('inferred'): xs.append('inferred=true')
        if x.get('shal'): xs.append('shal=true')
        if 'note' in x: xs.append('note={%s}'%','.join(luastr(t) for t in x['note']))
        st='u8' if f['st8'] else f['st']
        L.append(' F[#F+1]={%s,%d,%s,%s,%s,%s,%s,R.%s,{%s}}'%(luastr(f['path']),f['off'],luastr(st),luastr(f['group']),luastr(f['en']),luastr(f['zhs']),luastr(f['zht']),f['rng'],','.join(xs)))
    lay,nest=layout_lua(row)
    L.append(' S.TAB={%s,%s,%s}'%(luastr(en),luastr(zhs),luastr(zht)))
    L.append(' S.SUB=%s'%luastr(SUBOF[comp]))
    L.append(' S.FIELDS=F')
    L.append(' S.LAYOUT=%s'%lay)
    L.append(' S.NESTED=%s'%nest)
    if ORBITAL:
        dump=json.load(open(DUMP+comp+'.json',encoding='utf-8'))
        names={h[2:].upper():v['name'] for e in dump['entities'] for h,v in e.items()}
        L.append(' S.NAMES={%s}'%','.join('[%s]=%s'%(luastr(h),luastr(n)) for h,n in names.items()))
    L.append(' M.SPECS[#M.SPECS+1]=V.prepare(S)')
    L.append('end')
for e in sorted(used_enums):
    if e in CUSTOM_ENUMS: continue
    h=int(e[1:],16); n,vals=ENUM[h]
    vals={v:nm for v,nm in vals.items() if not re.search(r'_Unknown_\d+$|^Unknown_\d+$',nm)}
    items=','.join('[%d]={%s,%s,%s}'%(v,luastr(nm.split('_',1)[1] if nm.startswith(n+'_') else nm),luastr(nm.split('_',1)[1] if nm.startswith(n+'_') else nm),luastr(nm.split('_',1)[1] if nm.startswith(n+'_') else nm)) for v,nm in sorted(vals.items()) if not nm.endswith('_Count') and not nm.endswith('Count'))
    L.append('M.ENUMS[%s]={%s}'%(luastr(e),items))
for k,vals in sorted(CUSTOM_ENUMS.items()):
    L.append('M.ENUMS[%s]={%s}'%(luastr(k),','.join('[%d]={%s}'%(v,','.join(luastr(t) for t in tri)) for v,tri in sorted(vals.items()))))
L.append("M.SUBS={weapon={},type={},attach={},orbital={}}" if ORBITAL else "M.SUBS={weapon={},type={},attach={},mount={}}")
L.append("for _,s in ipairs(M.SPECS)do local t=M.SUBS[s.SUB];t[#t+1]=s.SLOT end")
L.append('return M')
open(os.environ.get('OUT',os.path.join(HERE,'..','..','offline','orbital_components.lua' if ORBITAL else 'weapon_components.lua')),'w',encoding='utf-8',newline='').write('\n'.join(L)+'\n')
print('lines',len(L))
