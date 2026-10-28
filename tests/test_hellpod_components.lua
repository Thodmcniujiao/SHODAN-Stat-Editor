-- The hellpods' components (offline/hellpod_components.lua, 实体组件 › 地狱舱): every field once, the descent's five
-- values at the offsets the 额外 page edits (one shared field each), and a page from a synthetic record.
-- python tests/run_lua.py tests/test_hellpod_components.lua   (no game files needed)
if not jit then
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local V=require('component_view')
local HP=require('hellpod_components')

-- four components, all in the 地狱舱 tabs
assert(#HP.SPECS==4 and #HP.SUBS.hellpod==4)
local count,by={},{}
for _,spec in ipairs(HP.SPECS)do
 assert(spec.SUB=='hellpod');count[spec.TYPE]=#spec.FIELDS;by[spec.TYPE]=spec
 local seen={};for _,s in ipairs(spec.FIELDS)do assert(not seen[s[1]],s[1]);seen[s[1]]=true end
end
assert(count.HellpodComponentData==26 and count.HellpodPayloadComponentData==3)
assert(count.HellpodRackComponentData==124 and count.ShipHellpodComponentData==1)
assert(by.HellpodComponentData.HASH==0x7EF5CC55 and by.HellpodPayloadComponentData.HASH==0xDDB5C03F)
assert(by.HellpodRackComponentData.HASH==0xA98BB156 and by.ShipHellpodComponentData.HASH==0x1E4344A9)
-- the descent: the 额外 page's offsets (+8 spawn height, +20..+32 speeds and braking), the variant's names
local d={};for _,s in ipairs(by.HellpodComponentData.FIELDS)do d[s[2]]=s end
assert(d[8][1]=='spawn_height'and d[20][1]=='initial_velocity'and d[24][1]=='breaking_height')
assert(d[28][1]=='breaking_velocity'and d[32][1]=='breaking_velocity_target_time')
assert(d[8][6]=='生成高度（米）'and d[32][6]=='制动时间（秒）')
assert(d[0][1]=='hellpod_variant'and HP.ENUMS[d[0][9].enum][2][2]=='初始空投'and HP.ENUMS[d[0][9].enum][1][2]=='增援')
local p={};for _,s in ipairs(by.HellpodPayloadComponentData.FIELDS)do p[s[2]]=s end
assert(p[0][1]=='remove_time'and p[4][1]=='life_time')
local r={};for _,s in ipairs(by.HellpodRackComponentData.FIELDS)do r[s[1]]=s end
assert(r['payloads[7].rack_side']and r['payloads[0].item'][9].entity and r.spawn_payload_size[2]==556)

-- a synthetic descent record (the initial drop's values), built into a page
local rec=string.pack('<I4BxxxfffffffB',2,1,1500,0,0,400,500,100,1,0)..string.rep('\0',104-37)
assert(#rec==104)
local KEY=string.pack('<I8',0x1122334455667788)
local fields={}
local function field_at(k,off,st,lim)
 local bit=st:match('^bit(%d)$');local key=k..':'..off..(bit and(':'..st)or'')
 fields[key]=fields[key]or{kind=k,offset=off,storage=bit and'flag'or st,mask=bit and 2^tonumber(bit),limit=lim,key=key,users={}};return fields[key]
end
local function read(f)
 local o=f.offset+1
 if f.storage=='flag'or f.storage=='u8'then return rec:byte(o)end
 if f.storage=='f32'then return(string.unpack('<f',rec,o))end
 if f.storage=='u64'then return(string.unpack('<I4',rec,o))end
 return(string.unpack('<I4',rec,o))
end
local function add_row(w,sec,id,label,st,parts,min,max)local row={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max};w.rows[#w.rows+1]=row;for _,q in ipairs(parts)do w.by_id[q.id]=q end;return row end
-- the 额外 page's field first (as the editor makes it), then the component page: the same field object
local extra=field_at(0x7EF5CC55,8,'f32',100000)
local res=V.build(by.HellpodComponentData,{table={index={[KEY]=0}},kind=0x7EF5CC55,weapons={},by_hash={},field_at=field_at,read=read,
 add_row=add_row,default_of=read,reference=function()end,log=function()end,lang=function()return'zh-Hans'end})
local page=res.pages[1];if page.ensure_rows then page.ensure_rows()end
local labels={}
for _,row in ipairs(page.rows)do
 assert(row.label_of()and row.section_of()and row.tip_of())
 labels[row.label_of()]=row
end
assert(labels['生成高度（米）'].parts[1].field==extra and read(extra)==1500)
assert(labels['地狱舱变体：初始空投'],'variant named')
print('hellpod components: ok ('..#page.rows..' rows)')
