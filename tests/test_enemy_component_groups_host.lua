-- Production enemy rows and collapse controls; all writes remain in isolated Data.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
prefix=prefix:gsub('save=save_config,','test_tables=tables,test_kinds=KINDS,render=draw,save=save_config,')
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
local function part(e,page,id)return assert(page.by_id[id],page.name..': missing '..id)end
local function close_all(e,page)
 e.select(page)
 for _,g in ipairs(page.component_groups)do if e.ui.expanded_components[page.hash..':'..g.type]then e.click('comp_toggle:'..g.type)end end
end
local function component(page,name)
 for _,g in ipairs(page.component_groups or{})do if g.type==name then return g end end
 error('missing component '..name..' on '..page.name)
end
local function displayed(e,id)
 for _,r in ipairs(e.MOD.parameter_rows(e.ui.weapon))do if r.id==id then return r end end
end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'enemy group host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS);local n,seaf,total=0,0,0
   assert(#H.diff()==0,'building presentation changed native data')
   for _,p in ipairs(e.weapons)do
    local expected=p.enemy and(e.MOD.ENEMY_SLOTS[p.slot]or p.slot=='SEAF')and #e.MOD.parameter_rows(p)>0
    if expected then
     assert(p.component_groups and p.enemy_component_rows,p.name..': enemy grouping missing')
     n=n+1;if p.slot=='SEAF'then seaf=seaf+1 end
     local seen,count,original={},0,{}
     for _,r in ipairs(p.enemy_component_rows)do original[r.id]=r end
     for _,g in ipairs(p.component_groups)do
      assert(e.ui.expanded_components[p.hash..':'..g.type],p.name..': not expanded by default')
      for _,r in ipairs(g.rows)do
       assert(not r.collapsed_component and r.collapsible and r.component==g.type)
       assert(not seen[r.id],p.name..': duplicate row '..r.id);seen[r.id]=true;count=count+1
       assert(r.parts==original[r.id].parts,p.name..': native parts or field identity changed: '..r.id)
      end
     end
     assert(count==#p.enemy_component_rows,p.name..': rows lost or duplicated')
     for _,r in ipairs(p.enemy_component_rows)do
      assert(seen[r.id]);local pref=require('parameter_preferences').identity(p,r,e.test_tables,e.test_kinds)
      assert(pref==r.parameter_identity,'pre-existing preference identity changed')
     end
     total=total+count
    elseif p.enemy and(p.slot=='Spawning'or p.slot=='EnemyData')then
     assert(not p.enemy_component_rows and not p.component_groups,'other enemy tabs were changed')
    end
   end
   assert(n>=250 and seaf>=8 and total>17000,'enemy/SEAF coverage too low')
   local page=assert(e.by_hash.F79CD8BB654397DF);local faction=assert(e.by_hash.FFFFFFFB00000002)
   local all=assert(e.by_hash.FFFFFFFB000000FE);local health=part(e,page,'health');local default=e.default_of(health.field)
   local health_group=component(page,'HealthComponentData')
   e.select(page);e.MOD.nav.sync();e.click('comp_toggle:HealthComponentData')
   assert(not e.ui.expanded_components[page.hash..':HealthComponentData'])
   local collapsed=false;for _,r in ipairs(page.rows)do if r.collapsed_component and r.component=='HealthComponentData'then collapsed=true end end
   assert(collapsed and #e.MOD.parameter_rows(page)==#page.enemy_component_rows)
   e.select(faction);e.select(page);assert(not e.ui.expanded_components[page.hash..':HealthComponentData'],'selection reopened a closed component')
   close_all(e,page);close_all(e,faction)
   local count_before=#page.enemy_component_rows
   -- Faction targets include closed components and apply exactly once.
   local fhealth=part(e,faction,'all_health');e.select(faction);e.change(fhealth.row,0,false,2)
   e.MOD.enemy.faction_refresh();assert(e.read(health.field)==default*2,'closed Health lost faction multiplication')
   local ftargets=#faction.enemy.targets.all_health.list
   assert(ftargets>50)
   e.select(all);e.change(part(e,all,'all_health').row,0,false,3);e.MOD.enemy.faction_refresh()
   assert(e.read(health.field)==default*6,'global/faction composition changed')
   e.select(page);e.change(health.row,0,false,default*5);e.MOD.enemy.faction_refresh()
   assert(e.read(health.field)==default*5,'individual enemy override was lost')
   -- Context preferences remain portable and do not multiply favorites twice.
   local writes=state.writes
   assert(e.MOD.parameters:set(faction,fhealth.row,'favorite',true))
   assert(e.MOD.parameters:set(faction,fhealth.row,'name','测试阵营生命'))
   e.MOD.parameter_refresh(faction);e.MOD.enemy.faction_refresh()
   assert(state.writes==writes and #faction.enemy.targets.all_health.list==ftargets)
   assert(e.read(health.field)==default*5)
   local header=component(faction,'HealthComponentData');e.select(faction);e.click('comp_toggle:HealthComponentData')
   e.MOD.parameter_refresh(faction);local found=false
   for _,r in ipairs(faction.rows)do if r.parameter_favorite and r.parts[1]and r.parts[1].field==fhealth.field then found=true end end
   assert(found,'favorite missing inside reopened component')
   -- Snapshot/preset application must see fields of folded components.
   e.select(page);TEST_PRESETS_HELPER.save(e,page,'enemy component snapshot')
   local values=TEST_PRESETS_HELPER.values(e,page,'enemy component snapshot')
   local stored=false;for _,v in ipairs(values)do if v.id=='health'and v.value==default*5 then stored=true end end;assert(stored)
   e.reset_row(page,health.row);e.MOD.enemy.faction_refresh();assert(e.read(health.field)==default*6)
   TEST_PRESETS_HELPER.load(e,page,'enemy component snapshot');assert(e.read(health.field)==default*5)
   e.reset_row(faction,fhealth.row);e.reset_row(all,part(e,all,'all_health').row);e.reset_row(page,health.row)
   e.MOD.enemy.faction_refresh();assert(e.read(health.field)==default)
   local sight=part(e,page,'sight');local sight_default=e.default_of(sight.field)
   e.select(page);e.change(health.row,0,false,default+100);e.change(sight.row,0,false,sight_default+5)
   close_all(e,page);e.click('reset_comp:HealthComponentData');e.MOD.enemy.faction_refresh()
   assert(e.read(health.field)==default and e.read(sight.field)==sight_default+5,'component reset crossed a group boundary')
   e.reset_row(page,sight.row)
   -- SEAF inventory and soldier health use the same component fold controls.
   local soldier
   for _,p in ipairs(e.weapons)do if p.slot=='SEAF'and p.enemy.members and p.by_id.health and p.by_id.gun_primary then soldier=p;break end end
   assert(soldier,'missing SEAF soldier with carried weapon')
   assert(component(soldier,'InventoryComponentData'))
   e.select(soldier);e.MOD.nav.sync();assert(e.ui.tab=='SEAF')
   local hp=part(e,soldier,'health');local base=e.default_of(hp.field)
   e.change(hp.row,0,false,base+100);close_all(e,soldier)
   TEST_PRESETS_HELPER.save(e,soldier,'SEAF snapshot');e.reset_row(soldier,hp.row)
   TEST_PRESETS_HELPER.load(e,soldier,'SEAF snapshot');assert(e.read(hp.field)==base+100)
   e.click('reset_weapon');e.MOD.enemy.faction_refresh();assert(e.read(hp.field)==base,'reset of a closed SEAF component failed')
   -- Weapon editor keeps its existing collapsed default.
   for _,p in ipairs(e.weapons)do if not p.enemy and p.lazy_components_attached then
    for _,g in ipairs(p.component_groups)do assert(not g.default_expanded,'weapon default was changed')end
   end end
   assert(#H.diff()==0,'grouping regression left native edits after reset')
   e.select(faction)
   for _,g in ipairs(faction.component_groups)do e.ui.expanded_components[faction.hash..':'..g.type]=true end
   faction.sync_rows();e.MOD.parameter_refresh(faction);e.MOD.nav.sync();e.ui.scroll=1;e.ui.message=nil;e.ui.version=e.ui.version+1
   print('Grouped '..n..' enemy/SEAF pages; '..seaf..' SEAF pages; '..total..' original rows')
   phase=1
  elseif phase==1 and state.phase=='ready'then
   assert(state.ui_errors==0,'enemy component display failed')
   local e=TEST_PARAMETERS;if not e.ui.gui or #e.ui.gui.items==0 then return true end
   S.save_bmp(TEST_WORK..'/enemy-components-expanded.bmp')
   local p=e.ui.weapon;e.click('comp_toggle:HealthComponentData')
   e.ui.gui.items={};e.render(S.w,S.h);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/enemy-components-folded.bmp')
   phase=2;return false
  end
 end
 return true
end
S.present=function()end;SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS enemy/SEAF components: default expansion, fold/selection, full canonical rows, faction/global/individual edits, favorites, preset and reset while folded; no game writes')
]==]
assert(loadstring(prefix..checks,'@enemy_component_groups_host'))()
