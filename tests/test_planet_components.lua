-- Planet settings (offline/planet_components.lua + planet_data.lua): names and their sources, the planets' display
-- names, and a page built from a synthetic LevelGenerationPlanetData record (no game files needed).
-- python tests/run_lua.py tests/test_planet_components.lua
if not jit then   -- (plain Lua: stand-ins for the parts of demolition.lua / preload_components.lua the module uses)
 local function hex(k)local t={}for i=8,1,-1 do t[#t+1]=string.format('%02X',k:byte(i))end return table.concat(t)end
 package.loaded.demolition={hex=hex,hash_resource=function(s)
  local h=0;for i=1,#s do h=(h*131+s:byte(i))%4294967291 end
  local t={};for i=1,8 do t[i]=string.char(h%256);h=math.floor(h/256)end;return table.concat(t)end}
end
local LOC={}
package.loaded.preload_components=package.loaded.preload_components or{location=function(a)return LOC[a]end,data={catalog={}}}
local PC=package.loaded.preload_components
local DATA=require('planet_data')
local P=require('planet_components')

-- every member has a source; the counts the generator reported
local how={}
for _,t in pairs(DATA.schemas)do for _,m in ipairs(t.members)do
 assert(m.source,'member without a source');how[m.source]=(how[m.source]or 0)+1
 if m.source~='none'then assert(m.alias and DATA.zh[m.alias],'no Chinese label for '..tostring(m.alias))end
end end
assert((how.value or 0)>=200 and(how['value-constant']or 0)>0,'value-matched names missing')
-- names the values corrected (the type library moved them since the 2025 data)
local PD=DATA.schemas[146979202];local at={}
for _,m in ipairs(PD.members)do at[m.offset]=m end
assert(at[88].alias=='debug_name'and at[8].alias=='planet_name_loc')
assert(at[16].alias=='planet_description_loc'and at[16].source=='value')
local palette=DATA.schemas[at[176].type];assert(palette.members[1].alias=='asset_grading')
-- planets by their debug name
local n=0;for _ in pairs(DATA.planets)do n=n+1 end;assert(n>=250,n)
assert(DATA.planets.planet_000.en=='Super Earth'and DATA.planets.planet_000.zhs=='超级地球'and DATA.planets.planet_000.zht=='超級地球')
assert(P.translate_name('LevelGenerationPlanetData · planet_000 [#1]','zh-Hans')=='超级地球（planet_000 [#1]）')
assert(P.translate_name('LevelGenerationPlanetData · planet_000 [#1]','en')=='Super Earth（planet_000 [#1]）')
assert(P.translate_name('WeatherSettings · x [#2]','zh-Hant')=='天氣 · x [#2]')
assert(P.provenance('value',.87,'zh-Hans'):find('87%%'))
-- group keys to member chains
local chain=P.path_members(146979202,'o176.o44.o4.')
assert(#chain==3 and chain[1].m.alias=='palette_group_lowland')

-- a synthetic planet record: zeros, a debug name and one gameplay modifier
local size=PD.size
local function u64le(v)local t={};for i=1,8 do t[i]=string.char(v%256);v=math.floor(v/256)end;return table.concat(t)end
local rec={};for i=1,size do rec[i]='\0'end
local function put(off,s)for i=1,#s do rec[off+i]=s:sub(i,i)end end
local name_at=size;local mods_at=size+16
put(88,u64le(name_at))
put(424,u64le(mods_at));put(432,string.char(1,0,0,0,0,0,0,0))
local b=table.concat(rec)..'planet_000\0'..string.rep('\0',5)..u64le(0x1122334455667788)
local KINDS={};P.register(KINDS)
local address=2^32
LOC[address]='generated_planet_data.dl_bin#146979202:1'
local spec=KINDS[146979202];local kind=spec.group_key(b,address);spec.list[#spec.list+1]=kind
local tables={[kind]={copies={address},payload=#b}}
local fields={}
local function field_at(k,off,st,lim)local key=k..':'..off..':'..st;fields[key]=fields[key]or{kind=k,offset=off,storage=st,limit=lim,key=key,users={}};return fields[key]end
local function read(f)
 local o=f.offset+1;local st=f.storage
 if st=='u8'then return b:byte(o)end
 if jit then
  local ffi=require('ffi');local bytes=b:sub(o,o+3);assert(#bytes==4,'synthetic field outside its record')
  local value=ffi.new(st=='f32'and'float[1]'or'uint32_t[1]');ffi.copy(value,bytes,4)
  local x=tonumber(value[0])
  return x==x and x or nil
 end
 if st=='f32'then local x=string.unpack('<f',b,o);return x==x and x or nil end
 return string.unpack('<I4',b,o)
end
local function add_row(w,sec,id,label,st,parts,min,max)local r={section=sec,id=id,label=label,storage=st,parts=parts,min=min,max=max};w.rows[#w.rows+1]=r;for _,p in ipairs(parts)do w.by_id[p.id]=p end;return r end
-- schemas as the installed type library would give them
local schemas={};for h,t in pairs(DATA.schemas)do local ms={};for i,m in ipairs(t.members)do ms[i]={offset=m.offset,size=m.size,type=m.type,atom=m.atom,storage=m.storage,count=m.count}end;schemas[h]={size=t.size,members=ms}end
local lang='zh-Hans'
local pages=P.build({tables=tables,kinds=KINDS,weapons={},by_hash={},field_at=field_at,read=read,add_row=add_row,default_of=read,
 schemas=schemas,names={},lang=function()return lang end,log=print,bytes=function()return b end})
local p=pages.PlanetData[1];assert(p and P.translate_name(p.name,'zh-Hans'):find('超级地球'))
assert(p.search:find('Super Earth')and p.search:find('超级地球'))
p.ensure_rows()
-- one band, each group's rows together, the planet first
local seen,last={},nil
for i,r in ipairs(p.rows)do
 assert(r.component=='LevelGenerationPlanetData'and r.component_of()=='星球生成（LevelGenerationPlanetData）')
 if r.section~=last then assert(not seen[r.section],'group split: '..tostring(r.section));seen[r.section]=true;last=r.section end
 assert(r.label_of()and r.section_of()and r.tip_of())
end
assert(p.rows[1].label_of()=='星球'and p.rows[1].readonly_text():find('超级地球'))
local mod
for _,r in ipairs(p.rows)do if r.id=='planet_o424[0]'then mod=r end end
assert(mod and mod.hash64 and mod.label_of():find('玩法修饰'),'gameplay modifier row')
lang='en';assert(p.rows[1].label_of()=='Planet')
print('planet components: ok ('..n..' planets named, '..(how.value or 0)..' names matched by value)')
