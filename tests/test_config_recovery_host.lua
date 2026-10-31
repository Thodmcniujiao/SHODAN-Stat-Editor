local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local F=require('preset_files');local path=I.home..'/config.txt'
local bad='broken\0configuration'
assert(F.write(path,bad));assert(F.write(path..'.bak',table.concat({'hotkey F10','changes on','lang en','updates off',
 'cache_clear_on_exit off','steam_auto_config off','FFFFFFF800000001 health 77777',''},'\n')))
local phase,began=0,tonumber(ffi.C.GetTickCount64())
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'config recovery timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready' and phase==0 then
   local e=TEST_PARAMETERS;local w=e.by_hash.FFFFFFF800000001
   assert(e.row_value(w.by_id.health.row)==77777,'backup cache was not staged')
   assert(state.host_pending(),'recovered cache incorrectly became installed baseline')
   assert(e.save());assert(F.read(path):find('hotkey F10',1,true))
   assert(F.read(path..'.corrupt')==bad,'damaged source was lost')
   assert(e.settings.cache_clear_on_exit==false,'recovered settings lost')
   phase=1
  end
 end
 return phase<1
end
S.present=function()end
arg={[1]=panel};assert(loadfile(TEST_ROOT..'/offline/host.lua'))()
assert(phase==1);gdi.DeleteDC(S.dc)
print('PASS: real config backup recovery, damaged-file preservation and recovered cache distinct from installed values')
]==]
assert(loadstring(prefix..checks,'@config_recovery_host'))()
