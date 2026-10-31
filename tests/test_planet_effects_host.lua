local file=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(file:read('*a'):match('^(.-)local phase, changed, began'));file:close()
prefix=prefix:gsub('save=save_config}', 'save=save_config,cancel=function()finish_value(false)end}')
local checks=[==[
local began=tonumber(ffi.C.GetTickCount64());local phase=0
local function find(page,id)
 for n,r in ipairs(page.rows)do if r.id==id then return r,n end end
 error('missing assignment row '..id)
end
local function edit(e,state,page,id,text)
 local r,n=find(page,id);e.click('value:'..n);assert(e.ui.value)
 e.ui.value.text=text;e.ui.value.fresh=false;return state.commit_value()
end
local function action(e,page,id)local _,n=find(page,id);e.click('preload_action:'..n)end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'planet assignment UI timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_PARAMETERS);local V=require('planet_effect_view');local G=require('galactic_effect_view')
   local J=require('json_data');local model=V.model
   assert(#e.MOD.planet.pages.PlanetEffectAssignments==273)
   assert(V.name(0)=='超级地球','planet names did not match current settings hashes')
   assert(model:reset(0));assert(model:reset(256));assert(model:master(false))
   local writes=state.writes;local p=assert(V.by_index[0])
   assert(p.note_of():find('网络层劫持',1,true),'missing network-layer explanation')
   p.ensure_rows();assert(find(p,'steam_repair')and find(p,'steam_restart')and find(p,'steam_restore'),'Steam actions missing')
   e.select(p);e.MOD.nav.sync();assert(e.ui.tab=='PlanetEffectAssignments'and model.cfg.selected_planet==0)
   assert(e.MOD.record_names.jump('PlanetEffectAssignments','256')==V.by_index[256])
   assert(#e.MOD.planet.list('PlanetEffectAssignments','超级地球',e.settings.tr)==1)
   action(e,p,'choose_effect');local effect=e.ui.weapon
   assert(effect==G.by_id[1202]and e.ui.tab=='PlanetEffectIds')
   assert(find(effect,'assignment_target').custom_text():find('超级地球',1,true))
   action(e,effect,'assign_to_planet');assert(table.concat(model:effective(0),',')=='1202,1203')
   action(e,effect,'assignment_target');assert(e.ui.weapon==p)
   local master=find(p,'assignment_master');e.change(master,0,false,1);assert(model.cfg.enabled)
   assert(not G.model.cfg.enabled,'assignment switch enabled definition overrides')
   p.ensure_rows();e.MOD.parameter_refresh(p)
   assert(edit(e,state,p,'add_ids','1397,1202'),'manual add did not commit');p.ensure_rows();e.MOD.parameter_refresh(p)
   assert(#model:target(0).effects==2 and table.concat(model:effective(0),',')=='1202,1203,1397',J.encode(model.cfg))
   action(e,p,'remove_1202');p.ensure_rows();e.MOD.parameter_refresh(p)
   assert(table.concat(model:effective(0),',')=='1397','remove action failed: '..J.encode(model.cfg))
   assert(edit(e,state,p,'add_ids','1202'));p.ensure_rows();e.MOD.parameter_refresh(p)
   local before=J.encode(model.cfg);edit(e,state,p,'add_ids','999999')
   assert(e.ui.value and J.encode(model.cfg)==before);e.cancel()
   local other=V.by_index[256];e.select(other);e.MOD.nav.sync()
   assert(edit(e,state,other,'add_ids','1203'))
   assert(table.concat(model:effective(256),',')=='1203','icon selection enabled actual effect')
   assert(model:changed(0)and model:changed(256))
   local fresh=require('planet_effects').new();assert(fresh.cfg.enabled and #fresh:target(0).effects==2)
   assert(state.writes==writes and #H.diff()==0,'planet assignments dirtied native game data before cache clear')
   local saved=assert(I.read(model.path));e.click('cache_clear');e.click('cache_clear')
   assert(I.read(model.path)==saved,'clearing numeric cache deleted network assignments')
   assert(#H.diff()==0,'cache clear left native changes')
   local f=assert(io.open(TEST_WORK..'/ui_plan.json','wb'));f:write(saved);f:close()
   e.select(p);e.MOD.nav.sync();e.ui.message=nil;e.ui.version=e.ui.version+1;phase=1
  elseif state.phase=='ready'and phase==1 then
   assert(state.ui_errors==0,'planet assignment draw failed')
   local gui=TEST_PARAMETERS.ui.gui
   if gui and #gui.items>0 then S.save_bmp(TEST_WORK..'/planet-effects.bmp');phase=2;return false end
  end
 end
 return true
end
S.present=function()end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
assert(require('planet_effects').new().cfg.enabled,'closing deleted assignments')
print('PASS production planet UI: 273 targets, select/browse/add/remove, actual/icon separation, portable restart, cache clear, rendering; no game writes')
]==]
assert(loadstring(prefix..checks,'@test_planet_effects_host.lua'))()
