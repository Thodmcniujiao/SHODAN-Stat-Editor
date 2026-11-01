-- Read-only extraction. Run with tests/run_lua.py --game ... --work ... --isolated-profile.
require('portable_io_guard')
local ffi=require('ffi');local G=require('gamedata');local D=require('demolition');local J=require('json_data')
local I=require('install');local S=require('game_texts');local A=require('archives');local data=require('planet_data')
I.mkdirs(TEST_WORK);local game=TEST_GAME..'/data/game'
local raw=assert(I.read(game..'/generated_planet_data.dl_bin'));local p,n=assert(G.open_sealed(raw))
local required,planets={},{}
local name_offset,debug_offset
for _,m in ipairs(data.schemas[146979202].members)do
 if m.alias=='planet_name_loc'then assert(m.storage==6 and m.size==4);name_offset=m.offset end
 if m.alias=='debug_name'then assert(m.storage==18 and m.size==8);debug_offset=m.offset end
end
assert(name_offset and debug_offset)
for _,h in ipairs(G.headers(p,n))do if h.type==146979202 then
 local P=p+h.at+24;local id=G.u32(P,name_offset)
 local off=tonumber(ffi.cast('uint64_t *',P+debug_offset)[0]);assert(off>=0 and off<h.size)
 local dn=ffi.string(P+off);local hash=tonumber(D.hex(D.hash_resource(dn)):sub(1,8),16)
 planets[#planets+1]={debug=dn,name_hash=id,settings_hash=hash};if id~=0 then required[tostring(id)]=true end
end end
G.free(p)
local effects=J.decode(assert(I.read(TEST_WORK..'/effects.json')))
if effects.galacticEffects then effects=effects.galacticEffects end
for _,e in ipairs(effects)do for _,k in ipairs({'nameHash','descriptionFluffHash','descriptionGamePlayLongHash','descriptionGamePlayShortHash'})do if e[k]~=0 then required[tostring(e[k])]=true end end end
local t=S.load(TEST_GAME..'/data',TEST_WORK..'/strings-index.bin','name-audit',function(d,p)return I.list_files(d,p)end)
local out={planets=planets,languages={},conflicts={},sources={},language_samples={},presence={},game_sources={}}
out.game_sources.planet={file='generated_planet_data.dl_bin',bytes=#raw}
local cipher=assert(I.read(game..'/generated_galactic_presence_settings.dl_bin'))
out.game_sources.presence={file='generated_galactic_presence_settings.dl_bin',bytes=#cipher,name_offset=32,description_offset=36}
local gp,gn=assert(G.open_sealed(cipher))
for _,h in ipairs(G.headers(gp,gn))do if h.type==4177128510 then
 local P=gp+h.at+24;local off=tonumber(ffi.cast('uint64_t *',P+8)[0]);assert(off>=0 and off<h.size);local debug=ffi.string(P+off)
 local item={debug=debug,settings_hash=tonumber(D.hex(D.hash_resource(debug)):sub(1,8),16),text_refs={}}
 for _,m in ipairs(data.schemas[h.type].members)do if m.storage==6 and m.atom==0 and m.size==4 then
  local v=G.u32(P,m.offset);if v~=0 then item.text_refs[tostring(m.offset)]=v end
 end end
 out.presence[#out.presence+1]=item
end end
G.free(gp)
for _,f in ipairs(t.files)do
 local entry=t.store:directory(f.archive).by[f.key];local d=t.store:read(f.archive,entry.main[1],entry.main[2])
 local language=string.format('%08X',A.u32(d,12));out.languages[language]=out.languages[language]or{}
 for _,row in ipairs(S.texts_of(d))do
  local key=tostring(row[1]);local v=row[2]
  if (required[key]or language=='03F97B57'or language=='5942CCF7'or language=='9EBA952A')and type(v)=='string'and v~=''then
   local prev=out.languages[language][key]
   if prev and prev~=v then out.conflicts[#out.conflicts+1]={language=language,id=key,first=prev,other=v}end
   out.languages[language][key]=prev or v
  end
 end
 out.sources[#out.sources+1]={key=D.hex(f.key),archive=f.archive,language=language,size=#d}
end
for language,strings in pairs(out.languages)do out.language_samples[language]=strings[tostring(planets[1].name_hash)]or''end
local f=assert(io.open(TEST_WORK..'/game-localization.json','wb'));assert(f:write(J.encode(out,true)));f:close()
print('PASS extracted',#planets,'planet records,',#out.sources,'language files,',#out.conflicts,'conflicting translations')
