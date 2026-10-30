-- The Presets folder: one file per preset, named after it; the older single-file library imported once and the
-- last build's folder carried over; preset files copied in are picked up.
-- python tests/run_lua.py tests/test_preset_folder.lua   (no game files needed)
package.loaded.install=package.loaded.install or{read=function()end,move_file=function()return 1 end}
local L=require('preset_library');local J=require('json_data')
local FS={}
local function list(dir)
 local out={};for p in pairs(FS)do local d,n=p:match('^(.*)/([^/]+)$');if d==dir then out[#out+1]=n end end
 table.sort(out);return out
end
local fs={read=function(p)return FS[p]end,write=function(p,s)FS[p]=s;return true end,
 move=function(a,b)FS[b]=FS[a];FS[a]=nil;return true end,remove=function(p)FS[p]=nil end,list=list}
local hash='EF85D6CF58E31D70'
-- the first global-preset builds: one preset_library.json
local old=L.new{path='B1/Presets/preset_library.json',io=fs}
assert(old:create('global','Horde',{values={{hash=hash,id='health',value=2}}}))
assert(old:create('global','精英',{values={}}))
assert(old:create('global','A/B:C?',{values={}}))
local lib=L.new{dir='B2/Presets',io=fs}
local ok,n=lib:import_library('B1/Presets/preset_library.json');assert(ok and n==3,tostring(n))
local files=list('B2/Presets')
assert(table.concat(files,',')=='A_B_C_.json,Horde.json,preset_index.json,精英.json',table.concat(files,','))
local horde=J.decode(FS['B2/Presets/Horde.json']);assert(horde.format==L.FORMAT and horde.name=='Horde'and horde.values[1].value==2)
-- rename / delete move and remove the files; two presets of one name stay apart
local id=lib:list()[3].id   -- (A/B:C? renamed 精英: the second 精英)
assert(lib:rename(id,'精英'));files=table.concat(list('B2/Presets'),',')
assert(files=='Horde.json,preset_index.json,精英 (2).json,精英.json',files)
assert(lib:delete(lib:list()[1].id));assert(not FS['B2/Presets/Horde.json'])
assert(lib:create('global','CON',{values={}}));assert(FS['B2/Presets/_CON.json'])
-- reopening reads the files back; importing again adds nothing; a deleted import does not return
local again=L.new{dir='B2/Presets',io=fs};assert(#again:list()==#lib:list())
ok,n=again:import_library('B1/Presets/preset_library.json');assert(ok and n==0)
-- a preset file copied in (from someone else: a clashing id) is picked up with a new id
local shared=J.decode(FS['B2/Presets/精英.json']);shared.name='Shared';FS['B2/Presets/Shared.json']=J.encode(shared)
FS['B2/Presets/notes.json']='{"mine":true}'
local picked=L.new{dir='B2/Presets',io=fs,log=function()end}
local names={};local ids={};for _,p in ipairs(picked:list())do names[#names+1]=p.name;assert(not ids[p.id]);ids[p.id]=true end
assert(table.concat(names,','):find('Shared'),table.concat(names,','))
assert(FS['B2/Presets/notes.json']=='{"mine":true}','a file that is not a preset is left alone')
-- the next build's folder: the last one carried over once
local nxt=L.new{dir='B3/Presets',io=fs}
ok,n=nxt:import_folder('B2/Presets');assert(ok and n==#picked:list(),tostring(n))
ok,n=L.new{dir='B3/Presets',io=fs}:import_folder('B2/Presets');assert(ok and n==0)
print('PASS: one file per preset (Unicode and unsafe names, duplicates, reserved names); rename/delete; reload; old library and last folder imported once; copied-in preset files picked up')
