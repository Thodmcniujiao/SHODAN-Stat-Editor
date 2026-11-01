-- Real editor + preset button, fresh host process per phase, isolated Data/Presets.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local F=require('preset_files');local J=require('json_data')
local mode=assert(os.getenv('SHODAN_NETWORK_HOST_PHASE'))
local phase,began=0,tonumber(ffi.C.GetTickCount64())
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'network switch host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS);local P=require('planet_effect_view');local G=require('galactic_effect_view')
   local planets,definitions=assert(P.model),assert(G.model)
   local function check(a,d)
    assert(planets.cfg.enabled==a and definitions.cfg.enabled==d,'wrong current switches: '..mode)
    assert(require('network_proxy').enabled()==(a or d),'proxy sees different switch state')
   end
   local id
   if mode=='save_cache_off'then
    assert(planets:add(0,1202));assert(definitions:set(1202,'flags',123));assert(definitions:set(1202,'enabled',true))
    assert(planets:master(true));assert(definitions:master(true))
    id=assert(e.presets.new_full_preset());assert(e.presets.finish_rename(false))
    assert(F.write(I.home..'/network-host-preset-id.txt',tostring(id)))
    assert(planets:master(false));assert(definitions:master(false));check(false,false)
   else
    id=assert(tonumber(F.read(I.home..'/network-host-preset-id.txt')))
    check(mode=='reopen_on',mode=='reopen_on')
   end
   local preset=assert(e.presets.library:get(id))
   assert(preset.data.network.assignments.enabled and preset.data.network.definitions.enabled,'saved preset should remain ON')
   assert(state.open_workspace('presets'));e.presets.show(id)
   check(mode=='reopen_on',mode=='reopen_on') -- opening/selecting must not apply the preset
   if mode=='reopen_off_apply'then
    e.click('fpreset:load');check(true,true)
    assert(table.concat(planets:effective(0),',')=='1202,1203'and definitions:read(1202,'flags')==123)
   elseif mode=='reopen_on'then
    assert(planets:master(false));assert(definitions:master(false));check(false,false)
   end
   local expected=mode=='reopen_off_apply'
   assert(J.decode(assert(F.read(planets.path))).enabled==expected)
   assert(J.decode(assert(F.read(definitions.path))).enabled==expected)
   phase=1
  end
 end
 return phase<1
end
S.present=function()end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
assert(phase==1);gdi.DeleteDC(S.dc)
print('PASS real network preset/cache layers:',mode,'preset selection inert; explicit Load restores switches; restart reads current cache')
]==]
assert(loadstring(prefix..checks,'@network_switch_host'))()
