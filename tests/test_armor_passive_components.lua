local ffi=require('ffi');local A=require('armor_passive_components');local N=require('numeric_policy')
local P=require('parameter_preferences')
local function u32(v)return string.char(v%256,math.floor(v/256)%256,math.floor(v/65536)%256,math.floor(v/16777216)%256)end
local function f32(v)local f=ffi.new('float[1]',v);return ffi.string(f,4)end
local base=0x100000;local head=24
local function blob(mods,stats)
 local mo=56;local so=mo+#mods*16
 local out={u32(31),u32(2458412307),u32(1),u32(2),u32(base+head+mo),u32(0),u32(#mods),u32(0),
  u32(base+head+so),u32(0),u32(#stats),u32(0),u32(123),u32(0)}
 for _,m in ipairs(mods)do out[#out+1]=u32(m[1])..u32(m[2])..f32(m[3])..u32(m[4])end
 for _,s in ipairs(stats)do out[#out+1]=u32(s[1])..f32(s[2])..f32(s[3])end
 return table.concat(out)
end
local bytes=blob({{0xAF8B7112,2,.5,99},{0xAF8B7112,999,-2.5,0},{0,0,1,0}},{{13,7,1.3},{13,-2,.75}})
local idx,count=assert(A.parse(bytes,base,head));assert(count==5 and #idx.mods==3 and #idx.stats==2)
assert(idx.mods[1].type_offset==60 and idx.mods[1].offset==64 and idx.mods[1].description_offset==68)
assert(idx.mods[2].type==999 and idx.mods[3].id==0,'unknown operation/empty modifier was filtered')
assert(idx.stats[1].add_offset==108 and idx.stats[1].offset==112)
assert(not A.parse(bytes:sub(1,55),base,head))
local bad=bytes:sub(1,24)..u32(4294967295)..bytes:sub(29);assert(not A.parse(bad,base,head))
bad=bytes:sub(1,32)..u32(base+head+56)..u32(0)..bytes:sub(41);assert(not A.parse(bad,base,head),'overlapping arrays accepted')
local empty=blob({},{});assert(A.parse(empty,base,head))
local fields={};local page={hash='FFFFFFFE0000001F',slot='Armors',passive='armor passive 31',rows={},by_id={}}
local language=2
local c={text=function(t)return t[language]end,translate=function(s)return s end,joined={},mod_names={},stat_names={},
 part=function(id,kind,off,storage)
  local key=off..':'..storage;fields[key]=fields[key]or{kind=kind,offset=off,storage=storage,users={}}
  return{id=id,field=fields[key]}
 end,
 read=function(f)if f.storage=='u32' then return require('demolition').u32(bytes,f.offset)end end,
 add=function(p,section,id,label,storage,parts,min,max,small,big)
  local r={section=section,id=id,label=label,storage=storage,parts=parts,min=min,max=max,small=small,big=big}
  N.row(r);p.rows[#p.rows+1]=r
  for _,part in ipairs(parts)do p.by_id[part.id]=part;part.row=r end
  return r
 end}
A.build(page,idx,c);assert(#page.rows==22)
assert(page.by_id.mod_AF8B7112.field.offset==64 and page.by_id.mod_AF8B7112_2.field.offset==80)
assert(page.by_id.stat_13.field.offset==112 and page.by_id.stat_13_add.field.offset==108)
assert(page.by_id.stat_13_2 and page.by_id.stat_13_2_add,'duplicate stat target was hidden')
assert(page.by_id.mod_AF8B7112_type.row.label_of():find('倍率',1,true))
assert(page.by_id.mod_AF8B7112_2_type.row.label_of():find('999',1,true))
assert(page.by_id.mod_AF8B7112.row.min==-N.F32_MAX and page.by_id.mod_AF8B7112.row.max==N.F32_MAX)
assert(page.by_id.mod_AF8B7112_type.row.max==4294967295,'artificial operation bound imposed')
local original={parts=page.by_id.mod_AF8B7112.row.parts,id='mod_AF8B7112',section='Passive'}
assert(P.identity(page,original,{},{})==P.identity(page,page.by_id.mod_AF8B7112.row,{},{}),'old parameter preference identity changed')
language=1;assert(page.by_id.mod_AF8B7112_type.row.label_of():find('Multiply',1,true))
assert(page.by_id.passive_name_loc.row.label_of()=='Name text ID')
assert(page.by_id.passive_unknown_0x30.row.section_of()=='Other fields')
for _,r in ipairs(page.rows)do
 local notes=r.tip_of();assert(r.section_of()and r.armor_passive_path)
 local key=r.armor_passive_path:match('%.([^%.]+)$')or r.armor_passive_path
 assert(A.HELP[key]and notes[1]~=r.armor_passive_path,'missing plain-language help: '..key)
 for _,locale in ipairs(A.HELP[key])do assert(locale[1]and locale[2]and locale[3])end
end
language=2
local notes=table.concat(page.by_id.mod_AF8B7112_type.row.tip_of(),'\n')
assert(notes:find('100',1,true)and notes:find('尚未完整核实',1,true)and notes:find('原始字段',1,true))
assert(page.by_id.stat_13_add.row.tip_of()[2]:find('先乘后加尚未核实',1,true))
if TEST_FIXTURES then
 local f=assert(io.open(TEST_FIXTURES..'/dl_library.dl_typelib','rb'));local schemas=require('demolition').schemas(f:read('*a'));f:close()
 assert(A.check_layout(schemas));schemas[A.MODIFIER].members[2].offset=5
 assert(not A.check_layout(schemas)and not A.parse(bytes,base,head,schemas))
end
print('PASS armor fields: complete native records, unknown operations, duplicate targets, array bounds, signed floats, old IDs/preferences, live labels and strict layout checks')
