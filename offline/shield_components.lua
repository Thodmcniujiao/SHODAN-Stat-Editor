-- A component-first view of ShieldComponentData (护盾): every entity that has the component, every field of its
-- 344-byte record, in parameter groups (容量与充能, 形状与外观, 行为, 充能事件 1-4, 音效, 动画与特效, 未知字段).
-- The layout (offsets, types) follows the type-library dump of game 1.007.200 (Darctor/Helldivers2_RawData,
-- ShieldComponentData.json, 2026-10-20); fields without a name there keep the dump's unk_<type>_0x<offset> name.
-- Every field is shown: checked field by field against the game's type library and every value against the game's
-- data and the dump. At start the installed game's type library is checked again (M.LAYOUT); a difference (a game
-- update) is logged and shown under the page's title, without hiding any field.
-- Same field objects as the original pages (no duplicate value store): a field a shield page already has (SH-32,
-- SH-51, FX-12, G/SH-39) keeps saving under that page's config entry (health_owner, as on the Health page).
local D=require('demolition')
local M={SIZE=344}
local HASH=4294967295
M.COMPONENT={'Shield component','护盾组件（Shield）','護盾組件（Shield）'}
-- parameter groups, in page order
M.GROUPS={
 {'charge','Capacity and recharge','容量与充能','容量與充能'},
 {'shape','Shape and look','形状与外观','形狀與外觀'},
 {'behavior','Behaviour','行为','行為'},
 {'trigger1','Charge event 1','充能事件 1','充能事件 1'},
 {'trigger2','Charge event 2','充能事件 2','充能事件 2'},
 {'trigger3','Charge event 3','充能事件 3','充能事件 3'},
 {'trigger4','Charge event 4','充能事件 4','充能事件 4'},
 {'audio','Audio','音效','音效'},
 {'effects','Animation and effects','动画与特效','動畫與特效'},
 {'unknown','Unknown fields','未知字段','未知欄位'},
}
M.GROUP={};for i,g in ipairs(M.GROUPS)do M.GROUP[g[1]]={n=i,name={g[2],g[3],g[4]}}end
-- value ranges: smallest, largest, small step, big step, signed
local R={
 hp={0,10000000,50,250},sec={0,3600,.5,5},rate={0,1000000,10,50},m={0,1000,.1,1},ratio={0,1,.05,.1},
 raw={-1e9,1e9,.1,1,true},hash={0,HASH,1,1},flag={0,1,1,1},enum={0,255,1,1},
}
-- enums with known value names (the dump's enum lists); 'status': StatusEffectType, named by the status table
M.ENUMS={
 color={[0]={'None','无','無'},{'Illuminate blue','光能者蓝','光能者藍'},{'Helldivers orange','绝地潜兵橙','絕地潛兵橙'}},
 melee={[0]={'None','无','無'},{'Damage once, then disable zone shape','伤害一次后关闭区域形状','傷害一次後關閉區域形狀'},
  {'Damage once, then disable damage result','伤害一次后关闭伤害结果','傷害一次後關閉傷害結果'}},
}
M.ENUM_TYPE={color='ShieldColorFaction',melee='ShieldBlockMeleeType',status='StatusEffectType',
 shape='ShieldShapeType',receiver='HitEffectReceiverType'}
-- field name, offset, storage (f32 / u32 / flag / u64 / enum), group, English, 简体, 繁體, range, extra
-- extra: verified (the editor had it), enum (M.ENUMS key / 'status' / unnamed type), note
M.FIELDS={
 {'charge',76,'f32','charge','Shield capacity','护盾值','護盾值',R.hp,{verified=true}},
 {'recharge_delay',88,'f32','charge','Recharge delay (s)','受击后开始充能延迟（秒）','受擊後開始充能延遲（秒）',R.sec,{verified=true}},
 {'broken_recharge_delay',92,'f32','charge','Recharge delay once broken (s)','击破后开始充能延迟（秒）','擊破後開始充能延遲（秒）',R.sec,{verified=true}},
 {'recharge_rate',96,'f32','charge','Recharge rate (per s)','充能速率（每秒）','充能速率（每秒）',R.rate,{verified=true}},
 {'starter_charge_on_recharge',100,'f32','charge','Charge it comes back with','击破后恢复时的初始护盾值','擊破後恢復時的初始護盾值',R.hp,{verified=true}},
 {'start_offline',176,'f32','charge','Offline at start (s)','生成后离线时间（秒）','生成後離線時間（秒）',R.sec,
  {note={'Meaning read from the field name; not tested in game.','含义按字段名推断，未经游戏内测试。','含義按欄位名推斷，未經遊戲內測試。'}}},
 {'unk_float_0x0050',80,'f32','charge','Unknown float +0x50','未知浮点数 +0x50','未知浮點數 +0x50',R.raw},
 {'unk_float_0x0068',104,'f32','charge','Unknown float +0x68','未知浮点数 +0x68','未知浮點數 +0x68',R.raw},

 {'radius',0,'f32','shape','Radius (m)','半径（米）','半徑（米）',R.m,{verified=true}},
 {'shield_shape',324,'enum','shape','Shape type','护盾形状类型','護盾形狀類型',R.enum,{enum='shape'}},
 {'shield_node',4,'u32','shape','Attach node (hash)','挂载节点（哈希）','掛載節點（雜湊）',R.hash},
 {'visual_sphere_path',120,'u64','shape','Shield sphere model (resource hash)','护盾球模型资源哈希','護盾球模型資源雜湊',R.hash},
 {'inside_shield_opacity',228,'f32','shape','Opacity inside (0-1)','护盾内部不透明度（0-1）','護盾內部不透明度（0-1）',R.ratio},
 {'shield_color_type',232,'enum','shape','Colour','护盾颜色','護盾顏色',R.enum,{enum='color'}},
 {'unk_float_0x0070',112,'f32','shape','Unknown float +0x70','未知浮点数 +0x70','未知浮點數 +0x70',R.raw},

 {'block_melee_type',224,'enum','behavior','Melee blocking','近战阻挡方式','近戰阻擋方式',R.enum,{enum='melee'}},
 {'hit_effect_receiver_type',216,'enum','behavior','Hit effect receiver type','命中特效接收类型','命中特效接收類型',R.enum,{enum='receiver'}},
 {'inflict_pain',220,'flag','behavior','Inflicts pain','造成疼痛','造成疼痛',R.flag},
 {'linked_to_status_effect_volume',236,'flag','behavior','Linked to a status effect volume','关联状态效果区域','關聯狀態效果區域',R.flag},
 {'unk_enum_0x006C',108,'enum','behavior','Status effect type +0x6C','状态效果类型 +0x6C','狀態效果類型 +0x6C',R.enum,{enum='status'}},
 {'unk_bool_0x0054',84,'flag','behavior','Unknown switch +0x54','未知开关 +0x54','未知開關 +0x54',R.flag},
 {'unk_bool_0x00AC',172,'flag','behavior','Unknown switch +0xAC','未知开关 +0xAC','未知開關 +0xAC',R.flag},
 {'unk_bool_0x00AD',173,'flag','behavior','Unknown switch +0xAD','未知开关 +0xAD','未知開關 +0xAD',R.flag},
 {'unk_bool_0x00AE',174,'flag','behavior','Unknown switch +0xAE','未知开关 +0xAE','未知開關 +0xAE',R.flag},
 {'unk_bool_0x0150',336,'flag','behavior','Unknown switch +0x150','未知开关 +0x150','未知開關 +0x150',R.flag},
}
-- charge_event_triggers: 4 x 20 bytes from +240
M.TRIGGER={
 {'health_percent',0,'f32','Trigger at shield fraction (0-1)','触发时的护盾比例（0-1）','觸發時的護盾比例（0-1）',R.ratio},
 {'event_name',4,'u32','Event (hash)','事件名（哈希）','事件名（雜湊）',R.hash},
 {'reverse_event_name',8,'u32','Reverse event (hash)','反向事件名（哈希）','反向事件名（雜湊）',R.hash},
 {'event_sound',12,'u32','Event sound (hash)','事件音效（哈希）','事件音效（雜湊）',R.hash},
 {'reverse_event_sound',16,'u32','Reverse event sound (hash)','反向事件音效（哈希）','反向事件音效（雜湊）',R.hash},
}
for i=1,4 do for _,t in ipairs(M.TRIGGER)do
 local n=' '..i
 M.FIELDS[#M.FIELDS+1]={'charge_event_triggers['..(i-1)..'].'..t[1],240+(i-1)*20+t[2],t[3],'trigger'..i,
  t[4],t[5],t[6],t[7],{id='trigger'..i..'_'..t[1]}}
end end
for _,s in ipairs({
 {'shield_break_sound',136,'Break sound','破盾音效','破盾音效'},
 {'shield_unk_sound_0x008C',140,'Unknown sound +0x8C','未知音效 +0x8C','未知音效 +0x8C'},
 {'shield_online_sound',144,'Online sound','上线音效','上線音效'},
 {'shield_idle_loop_start_sound',148,'Idle loop start','待机循环音效开始','待機循環音效開始'},
 {'shield_idle_loop_stop_sound',152,'Idle loop stop','待机循环音效停止','待機循環音效停止'},
 {'shield_bubble_loop_start_sound',156,'Bubble loop start','气泡循环音效开始','氣泡循環音效開始'},
 {'shield_bubble_loop_stop_sound',160,'Bubble loop stop','气泡循环音效停止','氣泡循環音效停止'},
 {'shield_surface_loop_start_sound',164,'Surface loop start','表面循环音效开始','表面循環音效開始'},
 {'shield_surface_loop_stop_sound',168,'Surface loop stop','表面循环音效停止','表面循環音效停止'},
 {'shield_recharging_loop_start_sound',180,'Recharging loop start','充能循环音效开始','充能循環音效開始'},
 {'shield_recharging_loop_stop_sound',184,'Recharging loop stop','充能循环音效停止','充能循環音效停止'},
 {'shield_pass_through_sound',188,'Pass-through sound','穿过护盾音效','穿過護盾音效'},
 {'shield_pass_through_sound_avatar',192,'Pass-through sound (helldiver)','穿过护盾音效（潜兵）','穿過護盾音效（潛兵）'},
 {'shield_unit_coming_online_sound',200,'Unit coming online sound','单位上线音效','單位上線音效'},
 {'charge_event_trigger_audio_node',320,'Charge event audio node (hash)','充能事件音频节点（哈希）','充能事件音訊節點（雜湊）'},
})do M.FIELDS[#M.FIELDS+1]={s[1],s[2],'u32','audio',s[3]..(s[1]:find('node')and''or' (hash)'),
 s[4]..(s[1]:find('node')and''or'（哈希）'),s[5]..(s[1]:find('node')and''or'（雜湊）'),R.hash}end
for _,s in ipairs({
 {'shield_break_particles',128,'u64','Break particles (resource hash)','破盾粒子特效资源哈希','破盾粒子特效資源雜湊'},
 {'shield_recharging_loop_event_node',196,'u32','Recharging loop event node (hash)','充能循环事件节点（哈希）','充能循環事件節點（雜湊）'},
 {'shield_unit_coming_online_node',204,'u32','Unit coming online node (hash)','单位上线节点（哈希）','單位上線節點（雜湊）'},
 {'shield_activate_animation_event',208,'u32','Activate animation event (hash)','激活动画事件（哈希）','啟動動畫事件（雜湊）'},
 {'shield_deactivate_animation_event',212,'u32','Deactivate animation event (hash)','关闭动画事件（哈希）','關閉動畫事件（雜湊）'},
})do M.FIELDS[#M.FIELDS+1]={s[1],s[2],s[3],'effects',s[4],s[5],s[6],R.hash}end
M.FIELDS[#M.FIELDS+1]={'unk_uint32_0x0008',8,'u32','unknown','Unknown integer +0x08','未知整数 +0x08','未知整數 +0x08',R.hash}
for i=0,15 do
 local off=12+i*4
 M.FIELDS[#M.FIELDS+1]={'unk_array_0x000C['..i..']',off,'u32','unknown','Unknown array +0x0C ['..i..']',
  '未知数组 +0x0C [' ..i..']','未知陣列 +0x0C ['..i..']',R.hash,{id='unk_array_0x000C_'..i}}
end
M.FIELDS[#M.FIELDS+1]={'unk_uint64_0x0148',328,'u64','unknown','Unknown 64-bit value +0x148','未知64位值 +0x148','未知64位值 +0x148',R.hash}
-- page order: by group, then as listed
for i,s in ipairs(M.FIELDS)do s.n=i end
table.sort(M.FIELDS,function(a,b)local ga,gb=M.GROUP[a[4]].n,M.GROUP[b[4]].n;if ga~=gb then return ga<gb end;return a.n<b.n end)

-- the record's members in the type library: offset, bytes (the two inline arrays are one member each)
M.LAYOUT={}
do
 local seen={}
 for _,s in ipairs(M.FIELDS)do
  local off,size=s[2],s[3]=='u64'and 8 or s[3]=='flag'and 1 or 4
  if off>=12 and off<76 then off,size=12,64 elseif off>=240 and off<320 then off,size=240,80 end
  if not seen[off]then seen[off]=true;M.LAYOUT[#M.LAYOUT+1]={off,size}end
 end
 table.sort(M.LAYOUT,function(a,b)return a[1]<b[1]end)
end
M.TRIGGER_SIZE=20

-- true when the type library (schemas: type hash -> { size, members = { offset, size, count, type, ... } }) lays
-- the component's record out as M.LAYOUT; else nil, why (with the layout found, for the log)
function M.check_layout(schemas,kind)
 if type(schemas)~='table'then return nil,'no type library'end
 local t=schemas[kind]
 if not t or #t.members~=2 then return nil,'ShieldComponentData is not a keyed table in the type library'end
 local row=schemas[t.members[2].type]
 if not row then return nil,'no record type'end
 if row.size~=M.SIZE then return nil,'record is '..tostring(row.size)..' bytes, not '..M.SIZE end
 local members={}
 for _,m in ipairs(row.members)do members[#members+1]=m end
 table.sort(members,function(a,b)return a.offset<b.offset end)
 local got={}
 for _,m in ipairs(members)do got[#got+1]='+'..m.offset..':'..m.size..(m.count and m.count>1 and('x'..m.count)or'')end
 local found=' ('..table.concat(got,' ')..')'
 if #members~=#M.LAYOUT then return nil,'record has '..#members..' fields, not '..#M.LAYOUT..found end
 for i,m in ipairs(members)do
  local e=M.LAYOUT[i]
  -- (an inline array: its whole size, or one element's times the count)
  if m.offset~=e[1]or(m.size~=e[2]and m.size*(m.count or 1)~=e[2])then return nil,'record fields differ at +'..e[1]..found end
 end
 -- the charge event entry, when the library has its type: 5 fields of 4 bytes
 for _,m in ipairs(members)do if m.offset==240 then
  local entry=schemas[m.type]
  if entry then
   if entry.size~=M.TRIGGER_SIZE or #entry.members~=5 then return nil,'charge event entry is not 5 fields in 20 bytes'end
   local list={}
   for _,x in ipairs(entry.members)do list[#list+1]=x end
   table.sort(list,function(a,b)return a.offset<b.offset end)
   for i,x in ipairs(list)do if x.offset~=(i-1)*4 or x.size~=4 then return nil,'charge event entry fields differ'end end
  end
 end end
 return true
end

local function pick(lang,t)return lang=='zh-Hans'and t[2]or lang=='zh-Hant'and t[3]or t[1]end

function M.build(c)
 local out={pages={},by_entity={}}
 if not c.table then return out end
 local function lang()return c.lang and c.lang()or'en'end
 local function zh()local l=lang();return l=='zh-Hans'or l=='zh-Hant'end
 local full,why=M.check_layout(c.schemas,c.kind)
 out.full,out.why=full,why
 if full then require('component_names').apply(M,c.schemas,c.kind)end
 if c.log then c.log('shield: all '..#M.FIELDS..' fields'..(full and' (type library layout matches)'or(' -- the type library differs, check before editing: '..tostring(why))))end
 local names,owners,users={},{},{}
 for _,w in ipairs(c.weapons)do
  if w.key then names[w.key]=names[w.key]or w.name end
  if w.enemy and w.enemy.members then
   for i,m in ipairs(w.enemy.members)do names[m.key]=w.name..(#w.enemy.members>1 and(' · '..i)or'')end
  end
  for _,row in ipairs(w.rows)do for _,p in ipairs(row.parts)do
   if p.field.kind==c.kind and not owners[p.field.key]then owners[p.field.key]={weapon=w,part=p}end
  end end
 end
 local status_names={}   -- (StatusEffectType names, read once each)
 local function enum_name(s,v)
  local e=s[9]and s[9].enum
  if not e or v==nil then return nil end
  if e=='status'then
   if v==0 then return pick(lang(),{'None','无','無'})end
   if status_names[v]==nil then status_names[v]=c.status_name and c.status_name(v)or false end
   return status_names[v]or nil
  end
  local t=M.ENUMS[e];local n=t and t[v]
  return n and pick(lang(),n)or nil
 end
 local keys={}
 for key,at in pairs(c.table.index)do keys[#keys+1]=key;users[at]=(users[at]or 0)+1 end
 table.sort(keys,function(a,b)return D.hex(a)<D.hex(b)end)
 for _,key in ipairs(keys)do
  local at=c.table.index[key];local entity=D.hex(key)
  local path=(c.names or{})[entity]or''
  local name=names[key]or(path~=''and path:match('([^/]+)$'))or entity
  local hash=D.hex(D.hash_resource('shodan/components/shield/'..entity:lower()))
  assert(not c.by_hash[hash],'Shield component view hash collision')
  local page={name=name,hash=hash,key=key,slot='ShieldComponents',shield_component=true,
   entity_hash=entity,path=path,shield_offset=at,shared_count=users[at],rows={},by_id={},field_keys={}}
  page.note='ShieldComponentData · '..entity..' · '..users[at]..' entity reference(s) to this record'
  local short=not full and tostring(why):gsub(' %(.*$','')or nil
  page.note_of=function()
   if short then
    return 'ShieldComponentData · '..entity..(zh()and(' · 注意：游戏类型库与解析不一致（'..short..'），修改前请先核对')
     or(' · warning: the type library differs ('..short..'), check before editing'))
   end
   if zh()then
    return 'ShieldComponentData · '..entity..' · '..(users[at]>1 and('共用记录：'..users[at]..' 个实体，修改会一起生效')or'此实体的护盾组件')
   end
   return page.note
  end
  for _,s in ipairs(M.FIELDS)do
   local x=s[9]or{}
   do
    local field,off,storage,group,r=s[1],at+s[2],s[3],s[4],s[8]
    local id=x.id or field
    local section='Shield:'..group
    local row
    if storage=='u64'then
     local lo,hi=c.field_at(c.kind,off,'u32',HASH),c.field_at(c.kind,off+4,'u32',HASH)
     if c.read(lo)~=nil and c.read(hi)~=nil then
      row=c.add_row(page,section,id,s[5],'u64',{{id=id..'_lo',field=lo},{id=id..'_hi',field=hi}},0,HASH,1,1)
      row.hash64,row.lead=true,true
      page.field_keys[lo.key],page.field_keys[hi.key]=true,true
     end
    else
     local st=storage=='enum'and'u32'or storage
     local limit=st=='f32'and(x.verified and 1000000 or 1e12)or st=='flag'and 1 or HASH
     local f=c.field_at(c.kind,off,st,limit)
     if r[5]then f.signed=true end   -- (before the first read: negative values are refused otherwise)
     local value=c.read(f)
     if value~=nil then
      local max=r[2]
      if storage=='enum'and M.ENUMS[x.enum]then max=#M.ENUMS[x.enum]end
      row=c.add_row(page,section,id,s[5],st,{{id=id,field=f,health_owner=owners[f.key]}},
       math.min(r[1],value),math.max(max,value),r[3],r[4])
      page.field_keys[f.key]=true
     end
    end
    if row then
     row.component='ShieldComponentData'
     row.component_of=function()return pick(lang(),M.COMPONENT)end
     row.section_of=function()return pick(lang(),M.GROUP[group].name)end
     local f1=row.parts[1].field
     row.label_of=function()
      local label=pick(lang(),{s[5],s[6],s[7]})
      local e=enum_name(s,c.read(f1))
      return e and(label..(zh()and'：'or': ')..e)or label
     end
     row.tip_of=function()
      local lines={field,string.format('ShieldComponentData +0x%X · %s',s[2],
       storage=='u64'and'uint64 (exact decimal)'or storage=='enum'and(M.ENUM_TYPE[x.enum]or'enum')..' (u32)'or storage)}
      if x.enum and M.ENUMS[x.enum]then
       local t={}
       for v=0,#M.ENUMS[x.enum]do t[#t+1]=v..' = '..pick(lang(),M.ENUMS[x.enum][v])end
       lines[#lines+1]=table.concat(t,'; ')
      end
      if x.note then lines[#lines+1]=pick(lang(),x.note)
      elseif not x.resolved_name and(field:find('^unk_')or field:find('_unk_'))then
       lines[#lines+1]=pick(lang(),{'Meaning unknown; position and type checked against the type library.',
        '含义尚未确认；位置与类型已按类型库核对。','含義尚未確認；位置與類型已按類型庫核對。'})
      end
      if x.resolved_name then for _,line in ipairs(require('component_names').tip(x,lang()))do lines[#lines+1]=line end end
      return lines
     end
    end
   end
  end
  c.by_hash[hash]=page;out.pages[#out.pages+1]=page;out.by_entity[entity]=page
 end
 table.sort(out.pages,function(a,b)
  local an,bn=a.name~=a.entity_hash,b.name~=b.entity_hash
  if an~=bn then return an end
  if a.name==b.name then return a.entity_hash<b.entity_hash end
  return a.name:lower()<b.name:lower()
 end)
 return out
end
return M
