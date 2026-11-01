local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
prefix=prefix:gsub('save=save_config,','quick_tables=tables,render=draw,save=save_config,')
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
local mode=os.getenv('SHODAN_QUICK_TEST_PHASE')or'setup'
local function values(e,targets)local out={};for _,t in ipairs(targets)do out[t.key]=e.read(t.part.field)end;return out end
local function matches(e,targets,value)for _,t in ipairs(targets)do assert(e.read(t.part.field)==value,t.key)end end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'quick modification host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_PARAMETERS);local q=e.MOD.quick.model;local h=e.MOD.health_components.by_entity['4D1C334D294DFA97']
   local health=assert(e.MOD.quick.targets('god'));local stims=assert(e.MOD.quick.targets('stims'))
   assert(#health==8 and #stims==3,'expected main + default + six live parts, and three stim fields')
   assert(e.MOD.nav.PAGES[1].name[2]=='快速修改')
   local unused=e.read(h.by_id.zone6_health.field)
   local before=values(e,health);local needles=values(e,stims)
   e.click('nav:features:1');assert(e.ui.nav.page=='features'and e.ui.weapon==nil)
   if mode=='setup'then
    assert(not q:state('god').active and not q:state('stims').active)
    e.click('quick:god');assert(q:state('god').active);matches(e,health,99999)
    assert(e.read(h.by_id.zone6_health.field)==unused,'reserved body slots were modified')
    for _,t in ipairs(stims)do assert(e.read(t.part.field)==needles[t.key])end
    e.click('quick:stims');assert(q:state('stims').active,tostring(e.ui.message and e.ui.message.text));matches(e,stims,99)
    local snapshot=assert(e.presets.capture());assert(#snapshot.values==0,'quick effects leaked into preset values')
    assert(snapshot.data.game.quick_switches.god and snapshot.data.game.quick_switches.stims and snapshot.data.game.quick_restore==nil,require('json_data').encode(snapshot.data.game))
    -- Closing restores the pre-enable custom values, not the variable maximum or blindly vanilla.
    e.click('quick:god');for _,t in ipairs(health)do assert(e.read(t.part.field)==before[t.key],
     'disable failed '..t.key..': '..tostring(e.read(t.part.field))..' expected '..tostring(before[t.key])..'; '..tostring(e.ui.message and e.ui.message.text))end
    e.click('quick:stims');for _,t in ipairs(stims)do assert(e.read(t.part.field)==needles[t.key])end
    for round=1,8 do
     for _,id in ipairs({'god','stims'})do
      e.click('quick:'..id);assert(q:state(id).active,'repeat activation '..round..'/'..id..': '..tostring(e.ui.message and e.ui.message.text))
      e.click('quick:'..id);assert(not q:state(id).active,'repeat restore '..round..'/'..id..': '..tostring(e.ui.message and e.ui.message.text))
     end
    end
    local main=health[1];e.select(main.page);e.change(main.part.row,0,false,777)
    e.click('nav:features:1');e.click('quick:god');e.click('quick:god');assert(e.read(main.part.field)==777)
    e.reset_row(main.page,main.part.row)
    e.click('quick:god');local zone=health[3]
    e.select(zone.page);e.change(zone.part.row,0,false,4242)
    assert(e.read(zone.part.field)==4242,'manual component input did not set 4242: '..zone.key..' = '..tostring(e.read(zone.part.field)))
    assert(q:state('god').custom and not q:state('god').active,'manual component edits left a false gold state')
    e.click('nav:features:1');e.click('quick:god')
    assert(q:state('god').active,'reapply failed: '..tostring(e.ui.message and e.ui.message.text))
    e.click('quick:god')
    assert(not q:state('god').active,'restore after reapply failed: '..tostring(e.ui.message and e.ui.message.text))
    assert(e.read(zone.part.field)==4242,'reapplying a recipe discarded a manual component value: '..zone.key..' = '..tostring(e.read(zone.part.field))..'; '..tostring(e.ui.message and e.ui.message.text))
    e.reset_row(zone.page,zone.part.row)
    e.click('quick:god');e.click('quick:stims');matches(e,health,99999);matches(e,stims,99)
    local id=assert(e.presets.new_full_preset());assert(e.presets.finish_rename(false))
    local saved=assert(e.presets.library:get(id));assert(saved.data.game.quick_switches.god and saved.data.game.quick_switches.stims and saved.data.game.quick_restore==nil)
    e.click('quick:god');e.click('quick:stims');assert(not q:state('god').active)
    -- Selecting a preset does not apply a quick recipe; explicitly loading does.
    e.presets.library.selected=id;assert(not q:state('god').active)
    assert(e.presets.load_full_preset(id));assert(q:state('god').active and q:state('stims').active)
    matches(e,health,99999);matches(e,stims,99)
    e.click('nav:features:1');e.click('reset_nav_page')
    assert(not q:state('god').active and not q:state('stims').active,'page reset left a shortcut enabled')
    e.click('quick:god');e.click('quick:stims')
    -- Read actual encrypted output from the production writer, without installing.
    local G=require('gamedata');local changes=H.diff();assert(#changes==1,'only the shared entity table should change')
    for _,change in ipairs(changes)do
     local bytes=assert(H.build(change));local p,n=assert(G.open_sealed(bytes));assert(G.murmur64(p,n)==change.hash)
     local file=H.files[change.name];local origin=tonumber(ffi.cast('uintptr_t',file.p))
     for _,list in ipairs({health,stims})do for _,t in ipairs(list)do
      local f=t.part.field;local table=e.quick_tables[f.kind]
      local offset=table.copies[1]+24+f.offset-origin
      assert(tonumber(ffi.cast('uint32_t *',p+offset)[0])==t.target,'encrypted output did not contain recipe value '..t.key)
     end end
     G.free(p)
    end
    e.settings.cache_clear_on_exit=false;assert(e.save())
   elseif mode=='reopen'then
    assert(q:state('god').active and q:state('stims').active,'restart lost native values or gold state')
    e.click('quick:god');e.click('quick:stims');assert(not q:state('god').active and not q:state('stims').active)
    assert(e.read(health[1].part.field)==125,'restart lost pre-enable restore context')
    e.click('quick:god');e.click('quick:stims')
   elseif mode=='clear'then
    assert(q:state('god').active and q:state('stims').active)
    e.click('cache_clear');e.click('cache_clear')
    assert(not q:state('god').active and not q:state('stims').active)
    assert(not next(e.settings.quick_restore),'cache clear kept quick restore metadata')
    assert(#H.diff()==0)
    e.click('quick:god');e.click('quick:stims')
   else error('unknown quick test phase')end
   e.click('nav:features:1');e.ui.message=nil;e.ui.version=e.ui.version+1;phase=1
  elseif state.phase=='ready'and phase==1 then
   assert(state.ui_errors==0,'quick page draw failed')
   local e=TEST_PARAMETERS;local gold=0
   if not e.ui.gui or #e.ui.gui.items==0 then return true end
   for _,item in ipairs(e.ui.gui.items)do if item.text=='无敌'or item.text=='无限治疗针'then
    assert(item.c[2]==255 and item.c[3]==213 and item.c[4]==0,'active switch text is not gold');gold=gold+1
   end end
   assert(gold==2,'two gold switches were not rendered')
   local buttons={}
   for _,r in ipairs(e.ui.regions)do if r.key:match('^quick:')or r.key:match('^quick_pending:')then buttons[r.key]=r end end
   local god=assert(buttons['quick:god']);local stims=assert(buttons['quick:stims']);local pending=assert(buttons['quick_pending:3'])
   assert(god.h==pending.h and god.h==stims.h and god.y==pending.y and god.y==stims.y,'quick buttons do not share the compact flow')
   assert(god.w<100 and stims.w<180,'quick buttons are still oversized')
   for _,item in ipairs(e.ui.gui.items)do if item.text then
    assert(not item.text:find('99999',1,true)and not item.text:find('初始／补给',1,true),'explanation is visible without hovering')
    assert(not item.text:find('待研究',1,true),'quick switches were separated from the gray buttons')
   end end
   S.save_bmp(TEST_WORK..'/quick-modifications-'..mode..'.bmp')
   for _,id in ipairs({'god','stims'})do
    e.ui.hover='quick:'..id;e.ui.gui.items={};e.render(S.w,S.h)
    local shown=false;local needle=id=='god'and'99999'or'初始／补给／最大'
    for _,item in ipairs(e.ui.gui.items)do if item.text and item.text:find(needle,1,true)then shown=true end end
    assert(shown,'quick button hover explanation is missing: '..id)
    S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/quick-hover-'..id..'-'..mode..'.bmp')
   end
   e.ui.hover=nil;e.ui.gui.items={};e.render(S.w,S.h)
   for _,item in ipairs(e.ui.gui.items)do if item.text then assert(not item.text:find('99999',1,true),'hover text remained after leaving button')end end
   phase=2;return false
  end
 end
 return true
end
S.present=function()end;SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS quick modifications '..mode..': exact player health/parts and inventory, independent gold switches, reversible values, global preset/cache, encrypted entity output and native rendering; no game writes')
]==]
assert(loadstring(prefix..checks,'@test_quick_modifications_host.lua'))()
