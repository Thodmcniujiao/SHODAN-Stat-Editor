local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'armor host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS);local first,second
   for _,a in ipairs(e.weapons)do if a.armor and a.default[1]then
    for _,b in ipairs(e.weapons)do if b.armor and a~=b and b.default[1]==a.default[1]then first,second=a,b;break end end
    if first then break end
   end end
   assert(first and second,'per-armor pages were not created')
   local other;for _,w in ipairs(e.weapons)do if w.passive then local id=e.MOD.kits.list_of(first)[1]
    if w.hash~=string.format('FFFFFFFE%08X',id)then other=tonumber(w.hash:sub(9),16);break end
   end end;assert(other)
   local original=table.concat(e.MOD.kits.list_of(second),',')
   e.select(first);e.click('stack_add:'..other)
   assert(#e.MOD.kits.list_of(first)==2 and table.concat(e.MOD.kits.list_of(second),',')==original)
   e.click('stack_del:'..first.default[1]);assert(#e.MOD.kits.list_of(first)==1 and e.MOD.kits.list_of(first)[1]==other)
   assert(e.save());assert(I.read(I.home..'/config.txt'):find(string.format('armor_passive %08X %d',first.armor,other),1,true))
   local payload=assert(e.presets.capture());assert(payload.data.game.armor_passives[tostring(first.armor)][1]==other)
   local p=require('preset_details').build(payload,{by_hash=e.by_hash,navigation=e.MOD.nav.PAGES,tab_of=e.MOD.nav.tab_of,
    lang=function()return'zh-Hans'end,tr=e.settings.tr,default_value=state.vanilla})
   local found=false;for _,page in ipairs(p)do for _,section in ipairs(page.sections)do for _,r in ipairs(section.rows)do
    if r.id=='armor_passives:'..first.armor then found=true end
   end end end;assert(found,'armor combination missing from global preview')
   e.click('stack_reset');assert(not e.settings.armor_passives[first.armor])
   -- Existing per-armor choices win legacy migration; other matching armors migrate.
   e.settings.armor_passives[second.armor]={second.default[1]}
   e.settings.stacks[first.default[1]]={other};e.settings.own_off[first.default[1]]=true
   e.MOD.kits.migrate();assert(e.MOD.kits.list_of(first)[1]==other)
   assert(e.MOD.kits.list_of(second)[1]==second.default[1]and not e.settings.stacks[first.default[1]])
   for id in pairs(e.settings.armor_passives)do e.settings.armor_passives[id]=nil end
   state.writes=state.writes+1
   -- Exercise the actual global preset path with both live network models.
   local net=require('galactic_effect_view');local planets=require('planet_effect_view').model
   assert(planets:add(0,1202));assert(net.model:set(1202,'flags',123));assert(net.model:set(1202,'enabled',true))
   local id=assert(e.presets.new_full_preset());assert(e.presets.finish_rename(false))
   assert(planets:reset(0));assert(net.model:reset(1202));assert(e.presets.load_full_preset(id))
   assert(table.concat(planets:effective(0),',')=='1202,1203'and net.model:read(1202,'flags')==123)
   assert(not planets.cfg.enabled and not net.model.cfg.enabled)
   phase=1
  end
 end
 return phase<1
end
S.present=function()end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
assert(phase==1);gdi.DeleteDC(S.dc)
print('PASS: real armor UI, independent selection/removal/reset, portable save, legacy migration priority, preview and global preset network round trip; no game writes')
]==]
assert(loadstring(prefix..checks,'@armor_passives_host'))()
