-- 敌人设置 › AI设置 and 实体组件 › 接触伤害 (offline/enemy_components.lua, offline/ai_components.lua): the enemies' AI,
-- senses and contact damage components, every field once, at the offsets the enemy pages already edit; a page from a
-- synthetic AiCharacter record.   python tests/run_lua.py tests/test_enemy_components.lua   (no game files needed)
if not jit then
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local V=require('component_view')
local EC=require('enemy_components')
local AI=require('ai_components')
-- the tabs: AI设置 (AiEnemy, AiCharacter, the sensor eye again, SensorEar, SensorDanger, Targeting), 接触伤害
assert(table.concat(AI.SUBS.ai,',')=='AiEnemyComponents,AiCharacterComponents,AiSensorEyeComponents,SensorEarComponents')
local Creature=require('creature_components')
assert(Creature.SUBS.creature[2]=='SensorDangerComponents'and Creature.SUBS.creature[3]=='TargetingComponents')
assert(table.concat(AI.SUBS.overlap,',')=='OverlapDamageComponents')
-- 实体组件 › 炮塔与制导: the sensor ear again, beside the sensor eye (the same fields as AI设置's)
do local ear=AI.SPECS[#AI.SPECS]
 assert(table.concat(AI.SUBS.turret,',')=='TurretSensorEarComponents'and ear.TYPE=='SensorEarComponentData'and ear.KEY=='turret_sensor_ear')
 for _,s in ipairs(require('enemy_components').SPECS)do if s.TYPE=='SensorEarComponentData'then assert(s.FIELDS==ear.FIELDS and s.KEY=='sensor_ear')end end
end
local eye=AI.SPECS[3]
assert(eye.TYPE=='SensorEyeComponentData'and eye.KEY~='sensor_eye'and eye.FIELDS==require('sensor_eye_components').FIELDS,'the same fields as 炮塔与制导')
local by={}
for _,s in ipairs(EC.SPECS)do
 by[s.TYPE]=s
 local seen={};for _,f in ipairs(s.FIELDS)do assert(not seen[f[1]],f[1]);seen[f[1]]=true;assert(f[5]and f[6]and f[7])end
end
local n={};for t,s in pairs(by)do n[t]=#s.FIELDS end
assert(n.AiEnemyComponentData==193 and n.AiCharacterComponentData==22 and n.SensorEarComponentData==7)
assert(n.SensorDangerComponentData==3 and n.OverlapDamageComponentData==385 and n.TargetingComponentData==21)
assert(by.AiEnemyComponentData.HASH==0x9D0EEFB5 and by.AiCharacterComponentData.HASH==0x5FEF63C4)
local function at(spec)local o={};for _,f in ipairs(spec.FIELDS)do o[f[2]]=o[f[2]]or f[1]end;return o end
-- the enemy pages' movement speed (MOD.enemy.SPEEDS) and senses rows land on these members
local ai=at(by.AiEnemyComponentData)
local SPEEDS={[0]='guard',[36]='patrol',[60]='investigate',[100]='combat',[124]='combat.strafe',[152]='combat.drift',[244]='retreat',[276]='charge'}
for off,state in pairs(SPEEDS)do assert(ai[off]and ai[off]:find('^'..state:gsub('%.','%%.'))and ai[off]:find('speed$'),off..' '..tostring(ai[off]))end
-- the names the value check settled (the dump's own offset names)
assert(ai[612]=='unk_enum_0x0264'and ai[616]=='target_share_radius'and ai[628]=='unk_float_0x0274'and ai[632]=='task_marker_node')
assert(ai[688]=='unk_float_0x02B0'and ai[700]=='unk_float_0x02BC'and ai[704]=='unk_bool_0x02C0')
local ch=at(by.AiCharacterComponentData)
assert(ch[0]=='preferred_speed'and ch[4]=='maximum_speed')
assert(at(by.SensorEarComponentData)[4]=='hearing_multiplier')
-- suppression: SensorDanger +8 is miss_react (near misses count; the 2024 schema's ignore_stance is gone), its table 4
-- bytes after the records; Targeting +36 / +40 / +44 the flinch the enemy pages' suppression rows edit
local dg=at(by.SensorDangerComponentData)
assert(dg[0]=='danger_max'and dg[4]=='danger_sphere_radius'and dg[8]=='miss_react'and by.SensorDangerComponentData.SLACK==4)
local tg=at(by.TargetingComponentData)
assert(by.TargetingComponentData.HASH==0x2C0968D2 and tg[36]=='aim_flinch_multiplier'and tg[40]=='aim_flinch_decrease'and tg[44]=='aim_flinch_max')
-- a page from a synthetic AiCharacter record: the movement row the enemy page scales is the same field
local ffi=jit and require('ffi')
local rec=(ffi and ffi.string(ffi.new('float[2]',{3.5,6}),8)or string.pack('<ff',3.5,6))..string.rep('\0',72)
local KEY=string.char(0x3F,0x2E,0xD6,0x6B,0x9F,0x1E,0x51,0xD9)
local fields={}
local function field_at(k,off,st,lim)local bit=st:match('^bit(%d)$');local key=k..':'..off..(bit and(':'..st)or'');fields[key]=fields[key]or{kind=k,offset=off,storage=bit and'flag'or st,limit=lim,key=key,users={}};return fields[key]end
local function read(f)
 local o=f.offset+1
 if f.storage=='flag'or f.storage=='u8' then return rec:byte(o)end
 if ffi then return tonumber(ffi.cast(f.storage=='f32'and'const float *'or'const uint32_t *',ffi.cast('const uint8_t *',rec)+f.offset)[0])end
 return(string.unpack(f.storage=='f32'and'<f'or'<I4',rec,o))
end
local function add_row(w,sec,id,label,st,parts)local r={section=sec,id=id,label=label,storage=st,parts=parts};w.rows[#w.rows+1]=r;for _,p in ipairs(parts)do w.by_id[p.id]=p;p.field.users[#p.field.users+1]=w end;return r end
local enemy_speed=field_at(0x5FEF63C4,0,'f32',1000)   -- (the enemy page's 移动速度 part, made first)
local page={hash='x',rows={},by_id={},field_keys={}}
V.build(by.AiCharacterComponentData,{table={index={[KEY]=0}},kind=0x5FEF63C4,weapons={},by_hash={},page_for=function()return page end,
 field_at=field_at,read=read,add_row=add_row,default_of=read,lang=function()return'zh-Hans'end})
if page.ensure_rows then page.ensure_rows()end
assert(#page.rows==22)
local first
for _,r in ipairs(page.rows)do assert(r.label_of()and r.section_of()and r.tip_of());if r.parts[1].field.offset==0 then first=r end end
assert(first.parts[1].field==enemy_speed and first.label_of()=='偏好速度（米/秒）'and read(enemy_speed)==3.5)
print('enemy components: ok (631 fields in 6 components)')
