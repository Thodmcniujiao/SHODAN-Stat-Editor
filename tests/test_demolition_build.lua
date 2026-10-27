local ffi=require('ffi')
local G=require('gamedata')
local H=require('hostdata')
local D=require('demolition')
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local fixture=assert(TEST_FIXTURES)
local game=assert(TEST_GAME)
local model=D.new(read(fixture..'/generated_entities.dl_bin'),read(fixture..'/generated_destruction_settings.dl_bin'),read(fixture..'/dl_library.dl_typelib'))
local originals={}
for _,name in ipairs({'generated_entities.dl_bin','generated_destruction_settings.dl_bin'})do
 local f=read(fixture..'/'..name)
 originals[name]=G.seal(ffi.cast('const uint8_t *',f),#f)
end
local problems=H.load(game,originals)
assert(#problems==0,table.concat(problems,'; '))
local changes=H.diff();assert(#changes==0,'host relocation appeared as an edit')
local aliases,result=model:changes(changes,{EEF85D6CF58E31D70={['0:normal']=999}},H)
assert(#aliases==1 and #changes==2)
local out={}
for _,c in ipairs(changes)do
 local target=c.hash
 local sealed,why=H.build(c,print);assert(sealed,why)
 local p,n=G.open_sealed(sealed);assert(p and G.murmur64(p,n)==target)
 out[c.name]=ffi.string(p,n);G.free(p)
end
local checked=D.new(out['generated_entities.dl_bin'],out['generated_destruction_settings.dl_bin'],read(fixture..'/dl_library.dl_typelib'))
assert(checked.by_id.EEF85D6CF58E31D70.levels[1].value==999)
assert(checked.by_id.E7FF0FD4572F5996F.levels[1].value==model.by_id.E7FF0FD4572F5996F.levels[1].value)
assert(checked.data.templates[4].bytes==model.data.templates[4].bytes)
print('PASS: full host diff, private override, hash correction, sealing and authenticated reload; no game writes')
