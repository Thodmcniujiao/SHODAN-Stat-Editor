-- 敌人设置 › 刷怪编辑器 (offline/spawn_components.lua): the hive mind regrouped as 敌人生成's three groups (the same
-- fields as 任务编辑's), the SEAF objectives record, the page names; a page from a synthetic SEAF record.
-- python tests/run_lua.py tests/test_spawn_components.lua   (no game files needed)
if not jit then
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local V=require('component_view')
local MC=require('mission_components')
local SP=require('spawn_components')
assert(#SP.SPECS==2 and #SP.SUBS.spawn==2)
local hive,seaf=SP.SPECS[1],SP.SPECS[2]
assert(hive.TYPE=='HiveMindComponentData'and hive.SUB=='spawn'and hive.KEY~='hive_mind')
-- every field of the mission editor's hive mind, once, at the same offset and storage
local orig
for _,s in ipairs(MC.SPECS)do if s.TYPE=='HiveMindComponentData'then orig=s end end
assert(#hive.FIELDS==#orig.FIELDS)
local at={};for _,s in ipairs(orig.FIELDS)do at[s[1]]=s end
local group={}
for _,s in ipairs(hive.FIELDS)do
 local o=at[s[1]];assert(o and o[2]==s[2]and o[3]==s[3],s[1]);group[s[2]]=s[4]
 assert((s[9]or{}).id==(o[9]or{}).id,'ids kept: the fields are shared with 任务编辑')
end
-- 敌人生成's rows land in its three groups, and say so
for _,off in ipairs({316,376,128,1077})do assert(group[off]=='reinforce',off)end
for _,off in ipairs({496,436,976,1036})do assert(group[off]=='patrol',off)end
for _,off in ipairs({856,556,676,616,796})do assert(group[off]=='outpost',off)end
assert(group[0]=='other'and group[116]=='progress')
local note
for _,s in ipairs(hive.FIELDS)do if s[2]==320 then note=s[9].note end end
assert(note and note[2]:find('增援规模'),'scaled-by note')
for _,s in ipairs(orig.FIELDS)do if s[2]==320 then assert(not(s[9].note and s[9].note[2]:find('增援规模')),'mission spec untouched')end end
-- groups in page order: 增援, 巡逻, 前哨与生成点 first
local last=0
for _,s in ipairs(hive.FIELDS)do local n=hive.GROUP[s[4]].n;assert(n>=last);last=n end
-- names
assert(SP.translate_name('Hive mind: Terminids · 40 min · D337A7BF','zh-Hans')=='敌人调度：虫族 · 40 分钟任务 · D337A7BF')
assert(SP.translate_name('SEAF objectives (all factions)','zh-Hant')=='SEAF 目標（所有陣營）')
assert(SP.translate_name('Hive mind: Terminids · 40 min · D337A7BF','en')==nil)

-- SEAF objectives: the 所有阵营 page's offsets, a page from a synthetic record
local f={};for _,s in ipairs(seaf.FIELDS)do f[s[2]]=s end
assert(#seaf.FIELDS==24 and f[48][3]=='f32'and f[80][1]:find('patrol')and f[88][1]:find('reinforcement')and f[0][3]=='u32')
local rec=string.pack('<IIIIIfffffII'..string.rep('f',12),6,6,6,12,18,.25,.25,.5,1,1,10,18,155,155,165,165,80,80,100,100,1.6,1.6,1.6,1.6)
assert(#rec==96)
local KEY=string.pack('<I8',0xA56F9F7E8CD25D04)
local fields={}
local function field_at(k,off,st,lim)local key=k..':'..off..':'..st;fields[key]=fields[key]or{kind=k,offset=off,storage=st,limit=lim,key=key,users={}};return fields[key]end
local function read(x)if x.storage=='f32'then return(string.unpack('<f',rec,x.offset+1))end return(string.unpack('<I4',rec,x.offset+1))end
local function add_row(w,sec,id,label,st,parts)local r={section=sec,id=id,label=label,storage=st,parts=parts};w.rows[#w.rows+1]=r;for _,p in ipairs(parts)do w.by_id[p.id]=p end;return r end
local floor=field_at(0xD74E6E1A,80,'f32',100000)   -- (所有阵营's 巡逻频率下限, made first)
local res=V.build(seaf,{table={index={[KEY]=0}},kind=0xD74E6E1A,weapons={},by_hash={},field_at=field_at,read=read,add_row=add_row,
 default_of=read,log=function()end,lang=function()return'zh-Hans'end})
local page=res.pages[1]
assert(page.name=='SEAF objectives (all factions)'and #page.rows==24)
local by={};for _,r in ipairs(page.rows)do assert(r.label_of()and r.section_of()and r.tip_of());by[r.label_of()]=r end
assert(by['巡逻频率下限 1（倍）'].parts[1].field==floor and read(floor)>1.59)
assert(read(by['SEAF 增援冷却 1（秒）'].parts[1].field)==155)
print('spawn components: ok ('..#hive.FIELDS..' hive mind fields, '..#seaf.FIELDS..' SEAF fields)')
