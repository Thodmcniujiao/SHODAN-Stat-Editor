-- Real host and all ordinary buffers, read-only live game, isolated authoring data.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'install state timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready' then
   local e=assert(TEST_PARAMETERS);local page=e.by_hash.FFFFFFF800000001
   assert(page and page.by_id.health)
   local row=page.by_id.health.row;local before=e.row_value(row)
   -- Establish a verified successful baseline without authorizing game writes.
   assert(state.host_pending~=nil)
   local current=require('json_data').encode(H.fingerprints())
   local initial=state.host_pending()
   e.change(row,0,false,before+100);assert(state.host_pending(),'health edit was missed')
   e.change(row,0,false,before);e.MOD.enemy.faction_refresh()
   assert(require('json_data').encode(H.fingerprints())==current,'health undo changed other bytes')
   assert(state.host_pending()==initial,'health A -> B -> A remained dirty')
   local named
   for _,w in ipairs(e.weapons)do if e.MOD.rename.of(w)then named=w;break end end
   assert(named,'no text-editable entity found')
   local name_before=(e.MOD.rename.texts[named.hash]or{}).name
   e.MOD.rename.set(named,'name','Install-state test')
   assert(state.host_pending(),'text-only edit was missed')
   e.MOD.rename.set(named,'name',name_before or'')
   assert(state.host_pending()==initial,'text undo remained dirty')
   local preload=assert(rawget(_G,'SHODAN_PRELOAD_MODEL'));local old=preload:snapshot()
   assert(preload:mutate(function()preload.cfg.selected['7371C64D957E5C74']=true end))
   assert(state.host_pending(),'preload-only edit was missed')
   assert(preload:mutate(function()preload.cfg=old end));assert(state.host_pending()==initial,'preload undo remained dirty')
   local stacks=e.settings.stacks;local saved={};for k,v in pairs(stacks)do saved[k]=v end
   e.settings.stacks[1]={2};state.writes=state.writes+1;assert(state.host_pending(),'passives-only edit was missed')
   e.settings.stacks=saved;state.writes=state.writes+1;assert(state.host_pending()==initial,'passives undo remained dirty')
   local bridge=assert(rawget(_G,'SHODAN_DEMOLITION_BRIDGE'));local panel=bridge.panel
   local target
   for _,t in ipairs(panel.model.targets)do if not t.why and #t.levels>0 then target=t;break end end
   assert(target);local level=target.levels[1];local previous=(panel.values[target.id]or{})[level.key]
   assert(panel:set(target.id,level.key,level.value+1));assert(state.host_pending(),'demolition-only edit was missed')
   assert(panel:set(target.id,level.key,previous));assert(state.host_pending()==initial,'demolition undo remained dirty')
   phase=1
  end
 end
 return phase<1
end
S.present=function()end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
assert(phase==1)
gdi.DeleteDC(S.dc)
print('PASS: real host content-based dirty state, health undo, names, preload and passive stacks; no game writes')
]==]
assert(loadstring(prefix..checks,'@install_state_host'))()
