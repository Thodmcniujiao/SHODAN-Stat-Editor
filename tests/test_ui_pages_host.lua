-- Every editor page drawn on the real desktop host with real game data (Windows only; no game writes):
-- each main page, each sub-page, its first pages with every component expanded, the armor pages, presets and settings.
-- Any panel error fails with the page and the error.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local began=tonumber(ffi.C.GetTickCount64())
local steps,at,wait,visited,failures=nil,1,0,0,{}
local function body()
 assert(tonumber(ffi.C.GetTickCount64())-began<600000,'UI pages host timeout')
 local state=rawget(_G,'ShodanStatEditor');if not state then return true end
 assert(state.phase~='gave_up',state.status)
 if state.phase~='ready'then return true end
 local e=assert(TEST_PARAMETERS)
 if not steps then
  steps={}
  for _,page in ipairs(e.MOD.nav.PAGES)do for k,sub in ipairs(page.subs or{})do
   steps[#steps+1]={label=page.id..':'..k,run=function()e.click('nav:'..page.id..':'..k)end}
   steps[#steps+1]={label=page.id..':'..k..' expanded',run=function()
    local list=e.weapons_in(e.ui.tab)
    for n=1,math.min(3,#list)do local w=list[n]
     e.select(w)
     for _,g in ipairs(w.component_groups or{})do e.ui.expanded_components[w.hash..':'..g.type]=true end
     if w.sync_rows then w.sync_rows()end
    end
   end}
  end end
  steps[#steps+1]={label='armor pages',run=function()
   e.click('nav:armory:5')
   for _,w in ipairs(e.weapons_in('Armors'))do if w.armor then e.select(w);break end end
  end}
  steps[#steps+1]={label='galactic effect definitions (with description)',run=function()
   e.click('nav:planets:2');e.click('cat:PlanetEffectIds')
   local gev=require('galactic_effect_view')
   for _,id in ipairs({1,1202,1411,1416,1419,1431})do if gev.by_id[id]then e.select(gev.by_id[id])end end
  end}
  steps[#steps+1]={label='presets',run=function()e.click('presets')end}
  steps[#steps+1]={label='settings',run=function()e.click('workspace_back');e.click('settings')end}
  steps[#steps+1]={label='back',run=function()e.click('workspace_back')end}
 end
 if wait>0 then wait=wait-1;return true end
 local step=steps[at]
 if step and step.errors then
  if state.ui_errors>step.errors then failures[#failures+1]=step.label..': '..tostring(state.last_ui_error)end
  at=at+1;step=steps[at]
 end
 if not step then
  if #failures>0 then error(#failures..' page(s) failed to draw:\n'..table.concat(failures,'\n\n'))end
  return false
 end
 step.errors=state.ui_errors
 local ok,why=pcall(step.run);if not ok then failures[#failures+1]=step.label..' (action): '..tostring(why)end
 visited=visited+1;wait=3
 return true
end
S.pump=function()
 local ok,res=xpcall(body,debug.traceback)
 if not ok then io.stderr:write('FAIL: '..tostring(res)..'\n');io.stderr:flush();os.exit(1)end
 return res
end
S.present=function()end
arg={[1]=panel};assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
gdi.DeleteDC(S.dc)
print('PASS: '..visited..' page visits drawn with no panel error (every main page and sub-page, first pages with all components expanded, an armor page, presets, settings); no game writes')
]==]
assert(loadstring(prefix..checks,'@ui_pages_host'))()
