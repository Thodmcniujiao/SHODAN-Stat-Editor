-- Real editor/preset files and native fields, isolated portable profile; never writes game files.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
prefix=prefix:gsub('save=save_config,','render=draw,save=save_config,')
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
local function clone(v)return require('json_data').decode(require('json_data').encode(v))end
local function values(e,list)local out={};for _,t in ipairs(list)do out[t.key]=e.read(t.part.field)end;return out end
local function matches(e,list,expected)for _,t in ipairs(list)do assert(e.read(t.part.field)==expected,t.key)end end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'quick switch preset host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS);local q=e.MOD.quick.model;local P=e.presets
   local health,stims=assert(e.MOD.quick.targets('god')),assert(e.MOD.quick.targets('stims'))
   local function capture()return assert(P.capture())end
   local function save(name,p)p=p or capture();return assert(P.library:create('global',name,p,p.kind))end
   local function load(id)local ok,why=P.load_full_preset(id);assert(ok,why)end
   local function change(t,value)e.select(t.page);e.change(t.part.row,0,false,value);assert(e.read(t.part.field)==value)end
   local function reset()
    for _,id in ipairs({'god','stims'})do if e.settings.quick_restore[id]then assert(q:toggle(id,false))end end
    for _,list in ipairs({health,stims})do for _,t in ipairs(list)do e.reset_row(t.page,t.part.row)end end
    assert(#H.diff()==0,'reset left native effects')
   end
   assert(#H.diff()==0)
   local off_id=save('全部关闭')
   assert(q:toggle('god'));local god=capture()
   assert(god.data.game.quick_switches.god==true and god.data.game.quick_switches.stims==false)
   assert(god.data.game.quick_restore==nil and #god.values==0,'god mode serialized its health effects')
   local god_id=save('仅无敌',god)
   assert(P.count(P.library:get(god_id))==1,'one switch must count as one change')
   assert(q:toggle('god',false));P.show(god_id)
   assert(not q:state('god').active,'selecting a preset applied it')
   local detail=P.detail_pages(P.library:get(god_id));local feature
   for _,page in ipairs(detail)do
    if page.id=='features'then feature=page end
    if page.id=='player'then assert(page.count==0,'quick effect rows leaked into Player data')end
   end
   assert(feature and feature.count==1 and feature.sections[1].id=='QuickPlayer')
   local row=feature.sections[1].rows[1]
   assert(row.id=='god'and row.value=='开启'and row.baseline=='关闭'and row.changed)
   load(god_id);assert(q:state('god').active and not q:state('stims').active);matches(e,health,99999)
   assert(q:toggle('god',false));for _,t in ipairs(stims)do assert(e.read(t.part.field)==e.default_of(t.part.field))end
   -- Manual baselines are independent parameters; switching off after a load restores them.
   change(health[1],777);change(stims[1],9)
   assert(q:toggle('god'));assert(q:toggle('stims'));local both=capture()
   local manual={};for _,v in ipairs(both.values)do manual[v.hash..'/'..v.id]=v.value
    assert(v.value~=99999 and v.value~=99,'a generated effect was serialized')end
   assert(#both.values==2 and manual[health[1].key]==777 and manual[stims[1].key]==9)
   local both_id=save('开关与手动参数',both)
   reset();load(both_id);assert(q:state('god').active and q:state('stims').active)
   assert(q:toggle('god',false));assert(q:toggle('stims',false))
   assert(e.read(health[1].part.field)==777 and e.read(stims[1].part.field)==9,'pre-enable manual parameters were lost')
   -- Patch off before explicit parameter edits; omitted switches remain active.
   load(both_id)
   local patch={scope='global',kind='patch',values={{hash=health[1].page.hash,id=health[1].part.id,value=321}},
    data={version=3,game={stacks={},own_off={},armor_passives={},quick_switches={god=false}}}}
   load(save('关闭无敌并改血量',patch))
   assert(not q:state('god').active and q:state('stims').active and e.read(health[1].part.field)==321)
   load(off_id);assert(not q:state('god').active and not q:state('stims').active and #H.diff()==0)
   -- Merging the logical switch is one item and copies no expanded fields or undo data.
   local Merge=require('preset_merge');local off=P.library:get(off_id)
   local ref={store='game',key='quick_switches',id='god'}
   local plan=Merge.plan(god,off,{ref})
   assert(plan.changes==1 and plan.payload.data.game.quick_switches.god==true and #plan.payload.values==0)
   assert(plan.payload.data.game.quick_switches.stims==false and plan.payload.data.game.quick_restore==nil)
   load(save('合并无敌开关',plan.payload));assert(q:state('god').active and not q:state('stims').active)
   local merge_id=save('界面合并目标',clone(off));P.show(god_id);assert(P.merge_start())
   P.merge_toggle('page','features');assert(P.merge_count()==1)
   P.merge_target(tostring(merge_id));assert(P.merge_preview().changes==1);P.merge_apply()
   local merged=P.library:get(merge_id)
   assert(#merged.values==0 and merged.data.game.quick_switches.god and merged.data.game.quick_switches.stims==false)
   load(merge_id);assert(q:state('god').active and not q:state('stims').active)
   -- Old expanded presets remain compatible; overwriting them creates logical switch data.
   local legacy=clone(god);legacy.data.game.quick_switches=nil;legacy.values={}
   legacy.data.game.quick_restore=clone(e.settings.quick_restore)
   for _,t in ipairs(health)do legacy.values[#legacy.values+1]={hash=t.page.hash,id=t.part.id,value=t.target}end
   local legacy_id=save('旧版实际数值',legacy);reset();load(legacy_id)
   assert(q:state('god').active);assert(q:toggle('god',false));assert(e.read(health[1].part.field)==125)
   load(legacy_id);P.show(legacy_id);assert(P.confirm('overwrite',legacy_id)==false or e.ui.confirm)
   assert(P.confirm('overwrite',legacy_id))
   local upgraded=P.library:get(legacy_id)
   assert(upgraded.data.game.quick_switches.god==true and upgraded.data.game.quick_restore==nil and #upgraded.values==0)
   -- A later store failure rolls back exact native values and partial recipe undo context.
   reset();change(health[1],777);assert(q:toggle('god'));change(health[3],4242)
   local prior=values(e,health);local undo=require('json_data').encode(e.settings.quick_restore)
   assert(q:state('god').custom and not q:state('god').active)
   local N=require('network_preset');local real_apply=N.apply;local fail=true
   N.apply=function(...)if fail then fail=false;return nil,'injected network save failure'end;return real_apply(...)end
   assert(not P.load_full_preset(god_id),'injected store failure was accepted');N.apply=real_apply
   assert(require('json_data').encode(e.settings.quick_restore)==undo,'rollback lost undo context')
   for _,t in ipairs(health)do assert(e.read(t.part.field)==prior[t.key],'rollback changed '..t.key)end
   assert(q:state('god').custom and not q:state('god').active)
   local invalid=clone(god);invalid.data.game.quick_switches.god='on'
   assert(not P.load_full_preset(save('无效开关',invalid)))
   for _,t in ipairs(health)do assert(e.read(t.part.field)==prior[t.key])end
   assert(require('json_data').encode(e.settings.quick_restore)==undo)
   reset()
   -- Favorites and cache still use the existing native values; no named preset is applied during a refresh.
   assert(P.refresh(true));assert(not q:state('god').active and #H.diff()==0)
   e.MOD.workspace.open('presets');P.show(god_id)
   P.toggle_detail('page','features');P.toggle_detail('section','features/QuickPlayer')
   local quick
   for _,item in ipairs(P.details(P.library:get(god_id)))do if item.kind=='parameter'and item.entry.jump.quick=='god'then quick=item.entry end end
   assert(quick and e.MOD.preset_jump(quick),'quick preview jump failed')
   assert(e.ui.nav.page=='features'and e.ui.weapon==nil and not q:state('god').active,'preview jump applied a switch')
   assert(e.MOD.preset_back());P.show(god_id)
   local out=assert(io.open(TEST_WORK..'/semantic-preset.json','wb'));out:write(require('json_data').encode(P.library:get(god_id)));out:close()
   e.ui.message=nil;e.ui.version=e.ui.version+1;phase=1
  elseif phase==1 and state.phase=='ready'then
   assert(state.ui_errors==0,'quick switch preview rendering failed')
   local e=TEST_PARAMETERS;if not e.ui.gui or #e.ui.gui.items==0 then return true end
   local shown=false
   for _,item in ipairs(e.ui.gui.items)do if item.text then
    assert(not item.text:find('99999',1,true),'preview still shows expanded effect values')
    if item.text:find('无敌',1,true)then shown=true end
   end end
   assert(shown,'quick switch preview row missing')
   S.save_bmp(TEST_WORK..'/quick-switch-preset.bmp');assert(e.save());phase=2;return false
  end
 end
 return true
end
S.present=function()end;SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS quick switch presets: logical save/preview, explicit load, pre-enable manual values, independent patch/merge, off snapshot, legacy upgrade, full store-failure rollback, preview jump/back, native rendering; no game writes')
]==]
assert(loadstring(prefix..checks,'@quick_switch_presets_host'))()
