-- Each phase runs in a fresh Lua process with the same isolated portable Data.
local J=require('json_data');local I=require('install');local F=require('preset_files')
local Global=require('global_preset');local P=require('planet_effects');local G=require('galactic_effects')
assert(TEST_WORK and I.home:gsub('\\','/'):sub(1,#TEST_WORK+1)==TEST_WORK..'/','isolated portable profile required')
require('portable_io_guard');I.mkdirs(I.home)
local mode=assert(os.getenv('SHODAN_NETWORK_RESTART_PHASE'))
local planets=P.new{folder=I.home};local definitions=G.new{folder=I.home}
assert(not planets.error and not definitions.error)
SHODAN_PLANET_EFFECT_MODEL=planets;SHODAN_GALACTIC_EFFECT_MODEL=definitions
local c={game_settings=function()return{stacks={},own_off={}}end,values=function()return{}end,apply=function()return true end}
local function check(a,d)
 assert(planets.cfg.enabled==a,'assignment master not restored: '..mode)
 assert(definitions.cfg.enabled==d,'definition master not restored: '..mode)
 assert(J.decode(assert(F.read(planets.path))).enabled==a)
 assert(J.decode(assert(F.read(definitions.path))).enabled==d)
 assert(require('network_proxy').enabled()==(a or d),'proxy cannot see restored switches')
 assert(table.concat(planets:effective(0),',')=='1202,1203')
 assert(definitions:enabled(1202)and definitions:read(1202,'flags')==123,'per-effect state lost')
end
if mode=='on'then
 assert(planets:add(0,1202));assert(definitions:set(1202,'flags',123));assert(definitions:set(1202,'enabled',true))
 assert(planets:master(true));assert(definitions:master(true))
 local p=Global.capture(c);assert(F.write(I.home..'/network-preset.json',J.encode(p)))
 assert(planets:master(false));assert(definitions:master(false));assert(Global.apply(c,p));check(true,true)
elseif mode:match('^reopen_')then
 local name=mode:sub(8);check(name=='on'or name=='assignment',name=='on'or name=='definition')
 if name=='merge'then assert(planets:changed(256),'merged planet disappeared after restart')end
else
 local p=J.decode(assert(F.read(I.home..'/network-preset.json')))
 local a=mode=='assignment';local d=mode=='definition'
 p.data.network.assignments.enabled=a;p.data.network.definitions.enabled=d
 assert(planets:master(not a));assert(definitions:master(not d))
 if mode=='merge'then assert(planets:add(256,1397));p.kind='patch'end
 assert(Global.apply(c,p));check(a,d)
 if mode=='merge'then assert(planets:changed(256),'merge erased another planet')end
end
print('PASS network switch persistence:',mode,'assignments',tostring(planets.cfg.enabled),'definitions',tostring(definitions.cfg.enabled))
