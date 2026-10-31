local P=require('planet_effects');local J=require('json_data')
local files,fail={},false
local fs={read=function(p)return files[p]end,mkdir=function()return true end,
 write=function(p,v)files[p]=v;return true end,
 move=function(a,b)if fail then return nil,'disk failure'end;files[b]=files[a];files[a]=nil;return true end,
 remove=function(p)files[p]=nil end}
local function model()return P.new{folder='portable/Data',fs=fs}end
local m=model();assert(not m.error and not m.cfg.enabled and m.cfg.selected_planet==-1)
assert(#P.data.planets==273 and m.planets[0])
assert(m:select(0));assert(m.cfg.selected_planet==0)
assert(m:add(0,1202));assert(m:changed(0));assert(table.concat(m:effective(0),',')=='1202,1203')
assert(m:add(0,{1202,1397}));assert(#m:target(0).effects==2)
assert(m.cfg.definitions['1202'].effectType==40 and m.cfg.definitions['1203'].effectType==71)
assert(m:icons(0,false));assert(table.concat(m:effective(0),',')=='1202,1397')
local other=P.data.planets[#P.data.planets].index
assert(m:add(other,1203));assert(table.concat(m:effective(other),',')=='1203','icon alone added gameplay ID')
assert(not m:add(999999,1202));assert(not m:add(0,{1202,999999}));assert(#m:target(0).effects==2)
assert(not m:add(0,{}));assert(not m:add(0,1202.5))
assert(m:master(true));m=model();assert(m.cfg.enabled and m.cfg.selected_planet==other)
assert(#m:target(0).effects==2 and not m:target(0).include_icons)
local old=J.encode(m.cfg);local bytes=files[m.path];fail=true
assert(not m:remove(0,1202));assert(J.encode(m.cfg)==old and files[m.path]==bytes);fail=false
assert(m:remove(0,1202));assert(table.concat(m:effective(0),',')=='1397')
assert(m:reset(0));assert(not m:changed(0)and m:changed(other))
assert(m:reset(other));assert(m.cfg.enabled and not m:changed(other))
assert(m:reload());assert(not m:status())
-- Test live API planetActiveEffects reading, toggle_removed, set_replace, and effective_with_live
files['portable/Data/WarProxy/live_planet_effects.json']=J.encode({war_id=801,updated=100,total=3,planet_count=1,planets={['0']={1202,1203,1397}}})
m.live_at=nil
assert(#m:live_on(0)==3)
assert(table.concat(m:effective_with_live(0),',')=='1202,1203,1397')
assert(m:toggle_removed(0,1202) and m:is_removed(0,1202) and m:changed(0))
assert(table.concat(m:effective_with_live(0),',')=='1397','blocking 1202 with include_icons must also block paired icon 1203')
assert(m:toggle_removed(0,1202) and not m:is_removed(0,1202))
assert(m:set_replace(0,true) and m:replace_mode(0) and m:changed(0))
assert(#m:effective_with_live(0)==0,'replace mode with no additions must clear all live effects on planet')
assert(m:reset(0) and not m:changed(0))
files[m.path]='{broken';assert(not m:reload());assert(not m:master(false));assert(files[m.path]=='{broken')
print('PASS 273 planet assignments: separate actual/icon IDs, deduplication, atomic persistence/rollback, multiple planets, remove/reset, live API monitor/block/overwrite and cache-independent storage')
