-- Real settings UI, portable persistence, and host shutdown with no live proxy changes.
local file=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(file:read('*a'):match('^(.-)local phase, changed, began'));file:close()
prefix=prefix:gsub('S.set_title = function%(%) end', 'S.set_title = function(title)S.test_title=title end')
local checks=[==[
local policy=require('network_proxy');local close_preference
policy.editor_closed=function(value)close_preference=value;return true end
local mode=os.getenv('SHODAN_PROXY_TEST_PHASE')or'on'
local wanted=mode=='on'
local began=tonumber(ffi.C.GetTickCount64());local phase=0
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'proxy settings UI timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_PARAMETERS)
   local writes,diffs=state.writes,#H.diff()
   assert(e.settings.changes==true,'desktop parameter editing is disabled')
   e.settings.set_changes(false)
   assert(e.settings.changes==true,'legacy toggle disabled desktop editing')
   assert(S.test_title:match('^SHODAN Stat Editor ')and not S.test_title:find('Offline',1,true),S.test_title)
   assert(state.window_title==S.test_title,'settings title differs from window title')
   assert(state.proxy_stop_on_exit()==(mode=='off'),'unexpected persisted/default exit preference')
   assert(state.steam_auto_config()==(mode=='on'),'automatic Steam setting default/reopen differs')
   e.click('settings');assert(e.ui.settings)
   e.click('set:proxy_stop_on_exit:'..mode)
   e.click('set:steam_auto_config:'..(wanted and'off'or'on'))
   assert(state.steam_auto_config()==not wanted)
   assert(e.settings.proxy_stop_on_exit==wanted and state.proxy_stop_on_exit()==wanted)
   e.save();assert(I.read(I.home..'/config.txt'):find('proxy_stop_on_exit '..mode,1,true))
   assert(state.writes==writes and #H.diff()==diffs,'changing proxy settings modified game data')
   e.ui.message=nil;e.ui.version=e.ui.version+1;phase=1
  elseif state.phase=='ready'and phase==1 then
   assert(state.ui_errors==0,'proxy settings draw failed')
   local gui=TEST_PARAMETERS.ui.gui
   if gui and #gui.items>0 then S.save_bmp(TEST_WORK..'/proxy-settings-'..mode..'.bmp');phase=2;return false end
  end
 end
 return true
end
S.present=function()end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
assert(close_preference==wanted,'host did not forward saved exit preference')
local config=assert(I.read(I.home..'/config.txt'))
assert(config:find('proxy_stop_on_exit '..mode,1,true),'cache clear on close discarded proxy preference')
assert(config:find('steam_auto_config '..(wanted and'off'or'on'),1,true),'cache clear discarded Steam auto repair preference')
assert(require('steam_integration').test_enabled==not wanted,'host did not poll with the saved Steam setting')
print('PASS proxy settings '..mode..': UI toggle, portable save/reopen, cache-clear preservation, host shutdown, title; no game/proxy writes')
]==]
assert(loadstring(prefix..checks,'@test_proxy_settings_host.lua'))()
