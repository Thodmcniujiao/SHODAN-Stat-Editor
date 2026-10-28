-- ShieldComponentData view (offline/shield_components.lua): layout, groups, field sharing and the fallback.
-- python tests/run_lua.py tests/test_shield_components.lua   (no game files needed; memory is simulated)
if not jit then   -- (plain Lua: a stand-in for the parts of demolition.lua the module uses)
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local M=require('shield_components')

-- the layout: 83 fields, 49 members, 21 bytes of padding, unk_*_0xNNNN names at their offsets
assert(#M.FIELDS==83,#M.FIELDS);assert(#M.LAYOUT==49,#M.LAYOUT)
local bytes=0;for _,e in ipairs(M.LAYOUT)do bytes=bytes+e[2]end;assert(M.SIZE-bytes==21,M.SIZE-bytes)
for i=2,#M.LAYOUT do assert(M.LAYOUT[i][1]>=M.LAYOUT[i-1][1]+M.LAYOUT[i-1][2],'overlap at +'..M.LAYOUT[i][1])end
for _,s in ipairs(M.FIELDS)do
 local n=s[1]:match('0x(%x%x%x%x)$');if n then assert(tonumber(n,16)==s[2],s[1])end
 assert(M.GROUP[s[4]],s[1])
end

-- memory: three records; the type library laid out as M.LAYOUT
local K=function(n)return string.char(n,0,0,0,0,0,0,0)end
local mem={}
local function put(at,off,v)mem[at+off]=v end
for r=0,2 do
 local at=r*344
 for _,s in ipairs(M.FIELDS)do put(at,s[2],s[3]=='flag'and 0 or 0)end
 for _,s in ipairs(M.FIELDS)do if s[3]=='u64'then put(at,s[2]+4,0)end end
 put(at,0,30);put(at,76,2500);put(at,88,1);put(at,92,15);put(at,96,200);put(at,100,1000)
 put(at,232,1);put(at,224,2);put(at,108,24);put(at,104,-2.5);put(at,240,.75)
end
local fields={}
local function field_at(kind,off,st,lim)
 local k=kind..':'..off;fields[k]=fields[k]or{kind=kind,offset=off,storage=st,limit=lim,key=k,users={}};return fields[k]
end
local function read(f)
 local v=mem[f.offset];if v==nil then return nil end
 if v<(f.signed and -f.limit or 0)or v>f.limit then return nil end
 return v
end
local function add_row(w,sec,id,label,st,parts,min,max,small,big)
 local r={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max,small=small,big=big}
 w.rows[#w.rows+1]=r
 for _,p in ipairs(parts)do w.by_id[p.id]=p;p.row=p.row or r;p.field.users[#p.field.users+1]=w end
 return r
end
local function schemas(moved)
 local row={size=344,members={}}
 for _,e in ipairs(M.LAYOUT)do
  row.members[#row.members+1]={offset=e[1]+(moved and e[1]==228 and 4 or 0),size=e[1]==12 and 4 or e[2],count=e[1]==12 and 16 or 1,type=e[1]==240 and 77 or 1}
 end
 return{SH={size=32,members={{type=0},{type=99}}},[99]=row,
  [77]={size=20,members={{offset=0,size=4},{offset=4,size=4},{offset=8,size=4},{offset=12,size=4},{offset=16,size=4}}}}
end
local lang,logs='zh-Hans',{}
local index={[K(1)]=0,[K(2)]=344,[K(3)]=688,[K(4)]=0}
local function build(sc)
 fields={}
 local old={name='SH-32 Shield Generator Pack',hash='12C8D71AC3897A5C',rows={},by_id={}}
 add_row(old,'Shield','shield_capacity','Shield capacity','f32',{{id='shield_capacity',field=field_at('SH',76,'f32',1000000)}},0,1e6,50,250)
 local S=M.build({table={index=index},kind='SH',weapons={old},by_hash={},field_at=field_at,read=read,add_row=add_row,
  log=function(s)logs[#logs+1]=s end,schemas=sc,status_name=function(v)return v==24 and'BushLarge'or nil end,
  lang=function()return lang end})
 return S,old
end

local S,old=build(schemas())
assert(S.full,logs[#logs]);assert(#S.pages==4)
local p=S.by_entity['0000000000000001']
assert(#p.rows==83,#p.rows)
assert(p.note_of():find('共用记录：2'))
-- groups in page order, every row under the component's heading
local order,last={},nil
for _,row in ipairs(p.rows)do
 assert(row.component=='ShieldComponentData'and row.component_of()=='护盾组件（Shield）')
 local g=row.section_of();if g~=last then order[#order+1]=g;last=g end
end
assert(table.concat(order,',')=='容量与充能,形状与外观,行为,充能事件 1,充能事件 2,充能事件 3,充能事件 4,音效,动画与特效,未知字段',table.concat(order,','))
local by={};for _,row in ipairs(p.rows)do by[row.id]=row end
-- the old page's capacity is the same field object, owned by that page
assert(by.charge.parts[1].field==old.rows[1].parts[1].field and by.charge.parts[1].health_owner.weapon==old)
-- values, enum names, signed unknowns, u64 rows
assert(read(by.radius.parts[1].field)==30 and read(by.recharge_rate.parts[1].field)==200)
assert(by.shield_color_type.label_of()=='护盾颜色：光能者蓝',by.shield_color_type.label_of())
assert(by.block_melee_type.label_of()=='近战阻挡方式：伤害一次后关闭伤害结果')
assert(by.unk_enum_0x006C.label_of()=='状态效果类型 +0x6C：BushLarge')
assert(by.shield_color_type.max==2 and by.shield_shape.max==255)
assert(by.unk_float_0x0068.min<0 and read(by.unk_float_0x0068.parts[1].field)==-2.5)
assert(by.visual_sphere_path.hash64 and #by.visual_sphere_path.parts==2)
assert(by.trigger1_health_percent and read(by.trigger1_health_percent.parts[1].field)==.75)
assert(by.unk_array_0x000C_15 and by.unk_array_0x000C_15.parts[1].field.offset==72)
lang='en';assert(by.charge.label_of()=='Shield capacity'and by.charge.section_of()=='Capacity and recharge')

-- a type library that differs, or none: only the six known fields
-- a type library that differs, or none: every field still shown, with a warning
local S2=build(schemas(true));assert(not S2.full and logs[#logs]:find('differ at %+228'))
lang='zh-Hans'
for _,q in ipairs(S2.pages)do assert(#q.rows==83,#q.rows);assert(q.note_of():find('类型库与解析不一致'))end
local S3=build(nil);assert(not S3.full and logs[#logs]:find('no type library'))
print('shield components: ok')
