-- Modifiers by dimension: the mission components (offline/mission_components.lua), the operation modifiers and the
-- planet effect modifiers (offline/modifier_components.lua), from a synthetic delta storage and Modifier record.
-- python tests/run_lua.py tests/test_modifier_components.lua   (no game files needed)
if not jit then
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local LOC={}
package.loaded.preload_components=package.loaded.preload_components or{location=function(a)return LOC[a]end,data={catalog={}}}
local V=require('component_view')
local MC=require('mission_components')
local MD=require('modifier_data')
local P=require('planet_components')

-- the mission components: three, every field once, in the 任务编辑 tabs
assert(#MC.SPECS==3 and #MC.SUBS.mission==3)
local count={}
for _,spec in ipairs(MC.SPECS)do count[spec.TYPE]=#spec.FIELDS;assert(spec.SUB=='mission')end
assert(count.GameModeComponentData==23 and count.HiveMindComponentData==277 and count.GameModeMissionComponentData==6)
local gm={};for _,s in ipairs(MC.SPECS[1].FIELDS)do gm[s[2]]=s[1]end
assert(gm[4]=='reinforce_time'and gm[12]=='solo_reinforce_time'and gm[28]=='life_regen_time'and gm[40]=='map_size_override')
assert(MD.COMPONENTS[8].name=='GameModeComponentData'and MD.COMPONENTS[215].name=='HiveMindComponentData')
assert(MD.FIELDS.HiveMindComponentData[116][1]=='starting_time_limit')

-- a delta storage: one resource changing GameMode +40 (f32) and HiveMind +116 (f32), another changing Health +0
local function u32(v)return string.pack('<I4',v)end
local function u64(v)return string.pack('<I8',v)end
local KEY_OP,KEY_HP=string.pack('<I8',0x1111222233334444),string.pack('<I8',0x5555666677778888)
local head=80
local res_at,slot_at,comp_at=head,head+32,head+48
local delta_at=comp_at+36;local data_at=delta_at+36
local blob=table.concat({
 u64(res_at),u32(2),u32(0), u64(slot_at),u32(2),u32(0), u64(comp_at),u32(3),u32(0), u64(delta_at),u32(3),u32(0), u64(data_at),u32(12),u32(0),
 KEY_OP,u32(0),u32(0), KEY_HP,u32(1),u32(0),                       -- resources -> slots
 u32(2),u32(0), u32(1),u32(2),                                       -- slots -> (count, first component)
 u32(8),u32(0),u32(1), u32(215),u32(1),u32(1), u32(227),u32(2),u32(1),-- components (index, first delta, count)
 u32(40),u32(4),u32(0), u32(116),u32(4),u32(4), u32(0),u32(4),u32(8),-- deltas (offset, size, data)
 string.pack('<f',0.5),string.pack('<f',720),u32(600)})
assert(#blob==data_at+12)
local KINDS={};P.register(KINDS)
local DT=0x683E604F
KINDS[DT]={name='deltas',layout={[0]=res_at,[1]=slot_at,[2]=comp_at,[3]=delta_at,[4]=data_at}}
local tables={[DT]={copies={2^33},payload=#blob,index={[KEY_OP]=0,[KEY_HP]=1}}}
-- a Modifier record: id, byte, one group (the entity, the Health delta)
local ENT=0xEF66B417EDC3B1D6
local rec=u32(0x01137871)..'\1\0\0\0'..u64(24)..u32(1)..u32(0)..
 u64(56)..u32(1)..u32(0)..u64(64)..u32(1)..u32(0)..u64(ENT)..KEY_HP
local address=2^32
LOC[address]='generated_modifier_settings.dl_bin#3706338031:1'
local mspec=KINDS[0xDCEA3AEF];local kind=mspec.group_key(rec,address);mspec.list[#mspec.list+1]=kind
tables[kind]={copies={address},payload=#rec}
local BYTES={[DT]=blob,[kind]=rec}
local fields={}
local function field_at(k,off,st,lim)local key=k..':'..off..':'..st;fields[key]=fields[key]or{kind=k,offset=off,storage=st,limit=lim,key=key,users={}};return fields[key]end
local function read(f)
 local b=BYTES[f.kind];local o=f.offset+1
 if f.storage=='f32'then return(string.unpack('<f',b,o))end
 if f.storage=='u8'then return b:byte(o)end
 return(string.unpack('<I4',b,o))
end
local function add_row(w,sec,id,label,st,parts,min,max)local r={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max};w.rows[#w.rows+1]=r;for _,p in ipairs(parts)do w.by_id[p.id]=p end;return r end
-- the type library: the three components' records (their keyed tables' second member)
local schemas={}
local function comp(hash,size,layout)local rt=hash+1;schemas[hash]={size=32,members={{type=0},{type=rt}}};schemas[rt]={size=size,members=layout}end
comp(0x09E13FAC,76,{{offset=40,size=4,storage=8,atom=0,count=0,type=0}})
comp(0xD0207221,1084,{{offset=116,size=4,storage=8,atom=0,count=0,type=0}})
comp(0xB3915DE3,64,{{offset=0,size=4,storage=6,atom=0,count=0,type=0}})
local lang='zh-Hans'
local pages=P.build({tables=tables,kinds=KINDS,weapons={},by_hash={},field_at=field_at,read=read,add_row=add_row,default_of=read,
 schemas=schemas,names={},lang=function()return lang end,log=function()end,bytes=function(k)return BYTES[k]end})

-- 行动编辑: the delta that changes the game mode / hive mind, named after what it changes, both values editable
assert(#pages.OperationModifiers==1)
local op=pages.OperationModifiers[1];op.ensure_rows()
assert(P.translate_name(op.name,'zh-Hans'):find('地图大小覆盖'))
local byid={};for _,r in ipairs(op.rows)do byid[r.label_of()]=r end
local ms=byid['GameMode · 地图大小覆盖（0-1）'];local tl=byid['HiveMind · 任务时间限制（秒）']
assert(ms and tl,'operation rows')
assert(ms.parts[1].field.kind==DT and read(ms.parts[1].field)==0.5 and read(tl.parts[1].field)==720)
-- 星球设置: the Modifier, named after its delta, its entity named, the Health value editable
assert(#pages.PlanetModifiers==1)
local pm=pages.PlanetModifiers[1];pm.ensure_rows()
local labels={};for _,r in ipairs(pm.rows)do labels[#labels+1]=r.label_of()..'='..tostring(type(r.readonly_text)=='function'and r.readonly_text()or r.readonly_text or read(r.parts[1].field))end
local all=table.concat(labels,'\n')
assert(all:find('实体 1=轨道380MM高爆弹火力网'),all)
assert(all:find('Health · 生命值=600'),all)
lang='en';assert(op.rows[1].label_of():find('GameMode'))
print('modifier components: ok')
