local J=require('json_data');local N=require('network_preset');local Global=require('global_preset')
local disk,fail={},nil
local fs={read=function(p)return disk[p]end,write=function(p,s)disk[p]=s;return true end,
 remove=function(p)disk[p]=nil;return true end,mkdir=function()return true end,
 move=function(a,b)if fail==b then fail=nil;return nil,'injected definition save failure'end;disk[b],disk[a]=disk[a],nil;return true end}
local planets=require('planet_effects').new{folder='portable/Data',fs=fs}
local definitions=require('galactic_effects').new{folder='portable/Data',fs=fs}
SHODAN_PLANET_EFFECT_MODEL=planets;SHODAN_GALACTIC_EFFECT_MODEL=definitions
assert(planets:add(0,1202));assert(planets:master(true));assert(definitions:set(1202,'flags',123));assert(definitions:set(1202,'enabled',true));assert(definitions:master(true))
planets.cfg.proxy_path='MACHINE_PRIVATE_PATH';definitions.cfg.effects['1202'].base.private_key='PRIVATE_CA_DATA'
local values={{hash='EF85D6CF58E31D70',id='health',value=999}}
local c={game_settings=function()return{stacks={},own_off={}}end,values=function()return values end,
 apply=function(p)values=J.decode(J.encode(p.values));return true end,sync=function()end}
local p=Global.capture(c);assert(p.data.version==3)
local raw=J.encode(p);assert(not raw:find('MACHINE_PRIVATE_PATH',1,true)and not raw:find('PRIVATE_CA_DATA',1,true))
assert(p.data.network.assignments.icon_pairs['1202']==1203 and p.data.network.definitions.effects['1202'].changes.flags==123)
assert(planets:reset(0));assert(definitions:reset(1202))
assert(Global.apply(c,p));assert(planets.cfg.enabled and definitions.cfg.enabled,'saved network switches were not restored')
assert(table.concat(planets:effective(0),',')=='1202,1203'and definitions:read(1202,'flags')==123)
assert(definitions:enabled(1202),'per-effect selection was lost')
assert(planets:add(256,1397));local patch=J.decode(J.encode(p));patch.kind='patch'
assert(Global.apply(c,patch));assert(planets:changed(0)and planets:changed(256),'network merge erased another planet')
local before=J.encode(N.capture());local game_before=J.encode(values)
local bad=J.decode(J.encode(p));bad.data.network.assignments.war_id=-1
assert(not Global.apply(c,bad));assert(J.encode(N.capture())==before and J.encode(values)==game_before)
assert(planets:master(false));assert(definitions:master(true));assert(definitions:set(1202,'flags',456))
before=J.encode(N.capture());game_before=J.encode(values)
local saved_planets=disk[planets.path];local saved_definitions=disk[definitions.path]
fail=definitions.path;assert(not Global.apply(c,p),'failed store was accepted')
assert(J.encode(N.capture())==before and J.encode(values)==game_before,'global rollback lost pre-load values or switches')
assert(disk[planets.path]==saved_planets and disk[definitions.path]==saved_definitions,'disk rollback differs')
local old={scope='global',kind='snapshot',values={},data={version=2,game={stacks={},own_off={}}}}
assert(Global.apply(c,old));assert(J.encode(N.capture())==before,'old preset unexpectedly erased network plans')
local preview=require('preset_details').build(p,{by_hash={},navigation={},lang=function()return'en'end,tr=function(v)return v end})
local tabs={};for _,page in ipairs(preview)do for _,section in ipairs(page.sections)do tabs[section.id]=section.count end end
assert(tabs.PlanetEffectAssignments>0 and tabs.PlanetEffectIds>0,'network preset contents missing from preview')
print('PASS: global network capture, exact effect/icon IDs, definitions, saved switch restoration, additive merge, old presets, invalid war rejection, complete memory/disk rollback and preview; no proxy/Steam/certificate actions')
