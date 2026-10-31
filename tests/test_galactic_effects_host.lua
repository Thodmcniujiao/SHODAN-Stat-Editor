-- Production UI, actual installed definitions, isolated portable writes only.
local file=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(file:read('*a'):match('^(.-)local phase, changed, began'));file:close()
prefix=prefix:gsub('save=save_config}', 'save=save_config,cancel=function()finish_value(false)end}')
local checks=[==[
local began=tonumber(ffi.C.GetTickCount64());local phase=0
local function find(page,id)
 for n,r in ipairs(page.rows)do if r.id==id then return r,n end end
 error('missing row '..id)
end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'effect-definition host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_PARAMETERS);local V=require('galactic_effect_view');local G=require('galactic_effects')
   local J=require('json_data');local pages=assert(e.MOD.planet.pages.PlanetEffectIds)
   assert(V.model:reset(1202));assert(V.model:master(false))
   assert(#pages==312 and V.by_id[1202]and V.by_id[1203]);local matched=0
   for _,p in ipairs(pages)do if #p.local_definition_targets>0 then matched=matched+1 end end
   assert(matched==74,'expected 71 presence and 3 modifier links, got '..matched)
   assert(#V.by_id[1304].local_definition_targets==0)
   assert(#V.by_id[1202].local_definition_targets==0,'actual EnemyTag was confused with icon parameters')
   assert(#V.by_id[1203].local_definition_targets>0)
   assert(V.by_id[1373].local_definition_targets[1].name:find('illuminate_ritual_storm_lvl1',1,true))
   assert(V.by_id[1345].local_definition_targets[1].modifier_id==0xCDD51BC6)
   assert(#e.MOD.planet.list('PlanetEffectIds','illuminate_ritual_storm_lvl1',e.settings.tr)==1)
   local p=V.by_id[1202];e.select(p);e.MOD.nav.sync()
   assert(e.ui.tab=='PlanetEffectIds'and e.MOD.component_rows()==21)
   assert(e.MOD.record_names.jump('PlanetEffectIds','1203')==V.by_id[1203])
   assert(not e.MOD.record_names.jump('RecProjectile','1203')or e.MOD.record_names.jump('RecProjectile','1203')~=V.by_id[1203])
   assert(not e.MOD.record_names.is_page(p),'effect ID entered the TypeID name namespace')
   assert(e.settings.tr(p.name):find('[生效]',1,true))
   assert(e.settings.tr(V.by_id[1182].name):find('制空权',1,true),'UTF-8 reference title was truncated')
   assert(e.settings.tr(V.by_id[1191].name):find('穿刺虫激增',1,true))
   assert(find(p,'role').readonly_text():find('1203',1,true))
   local writes=state.writes;local values,n=find(p,'values')
   local icon=J.encode(V.model:read(1203,'values'))
   e.click('value:'..n);assert(e.ui.value and e.ui.value.text=='[2922304745,0]')
   e.ui.value.text='[2313485354,0]';e.ui.value.fresh=false;assert(state.commit_value())
   assert(V.model:read(1202,'values')[1]==2313485354)
   p.ensure_rows();e.MOD.parameter_refresh(p)
   assert(find(p,'enemy_tag').readonly_text=='GM_BugSuperPredators','reference did not follow edited payload')
   values,n=find(p,'values')
   assert(J.encode(V.model:read(1203,'values'))==icon,'editing actual payload also edited icon')
   local master=find(p,'network_master');local entry=find(p,'network_entry')
   e.change(master,0,false,1);e.change(entry,0,false,1)
   local saved=G.new();assert(saved.cfg.enabled and saved:enabled(1202))
   assert(saved:read(1202,'values')[1]==2313485354 and p.custom_modified())
   assert(state.writes==writes and #H.diff()==0,'network authoring dirtied native game files')
   assert(saved.path:gsub('\\','/'):sub(1,#TEST_WORK+1)==TEST_WORK..'/')
   -- A failed JSON edit keeps the text editor open and the previous plan intact.
   e.click('value:'..n);e.ui.value.text='[NaN]';e.ui.value.fresh=false;state.commit_value()
   assert(e.ui.value and V.model:read(1202,'values')[1]==2313485354)
   e.cancel();assert(not e.ui.value)
   e.reset_row(p,values);assert(V.model:read(1202,'values')[1]==2922304745)
   assert(p.custom_reset());assert(V.model:master(false))
   -- Pair navigation uses the independent ID page, then a real local source page.
   local peer=find(p,'paired_id');assert(peer.custom_action());assert(e.ui.weapon==V.by_id[1203])
   local iconpage=e.ui.weapon;assert(e.settings.tr(iconpage.name):find('[图标]',1,true))
   local localrow=find(iconpage,'local_1');assert(localrow.custom_action())
   assert(e.ui.weapon==iconpage.local_definition_targets[1]and e.ui.tab=='PlanetSpace')
   assert(#e.ui.weapon.rows>0)
   e.select(p);e.MOD.nav.sync();e.ui.message=nil;phase=1
  elseif state.phase=='ready'and phase==1 then
   assert(state.ui_errors==0,'effect UI draw failed')
   local gui=TEST_PARAMETERS.ui.gui
   if gui and #gui.items>0 then
    assert(#H.diff()==0);S.save_bmp(TEST_WORK..'/effect-id-definition.bmp');phase=2;return false
   end
  end
 end
 return true
end
S.present=function()end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2,'effect host checks did not finish');loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS production effect UI: 312 IDs, 74 local links, distinct actual/icon edits, jump/search, portable persistence and no game writes')
]==]
assert(loadstring(prefix..checks,'@test_galactic_effects_host.lua'))()
