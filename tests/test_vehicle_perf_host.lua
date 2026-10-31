-- Frame time of 军械库 › 战备编辑 › 载具 on the real desktop host (Windows only; no game writes), with a sampling
-- profile of the slowest code. Fails when a vehicle page takes longer than the budget per frame.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
local checks=[==[
local began=tonumber(ffi.C.GetTickCount64())
local function ms()return tonumber(ffi.C.GetTickCount64())end
local profile=require('jit.profile')
local samples,total={},0
local stage,pages,at,frames,last,times,report=0,nil,1,0,nil,{},{}
select_ms={}
local function body()
 assert(ms()-began<600000,'vehicle perf timeout')
 local state=rawget(_G,'ShodanStatEditor');if not state or state.phase~='ready'then return true end
 local e=assert(TEST_PARAMETERS)
 if stage==0 then
  e.click('nav:armory:4')
  pages={};for _,w in ipairs(e.weapons_in('Mechas'))do pages[#pages+1]=w end
  assert(#pages>0,'no Mechas pages')
  local t0=ms();e.select(pages[1]);select_ms={[1]=ms()-t0};stage=1;frames=0;last=ms()
  profile.start('fl',function(th,n)local s=profile.dumpstack(th,'l;',-6);samples[s]=(samples[s]or 0)+n;total=total+n end)
  return true
 end
 local now=ms();times[#times+1]=now-last;last=now;frames=frames+1
 e.ui.version=e.ui.version+1   -- force a full redraw every frame (hover, scrolling, typing all do)
 if frames==6 then   -- the second half: every component expanded
  local w=pages[at];for _,g in ipairs(w.component_groups or{})do e.ui.expanded_components[w.hash..':'..g.type]=true end
  local t0=ms();if w.sync_rows then w.sync_rows()end;expand_ms=ms()-t0
 end
 if frames>=12 then
  local list={};for _,t in ipairs(times)do list[#list+1]=t end;table.sort(list)
  local a,b={},{};for k,t in ipairs(times)do if k<=6 then a[#a+1]=t else b[#b+1]=t end end;table.sort(a);table.sort(b)
  worst=math.max(worst or 0,a[math.ceil(#a/2)],b[math.ceil(#b/2)])
  report[#report+1]=string.format('%-40s select %4d ms | collapsed redraw median %4d ms | expanded (%d ms) redraw median %4d max %4d ms',
   pages[at].name,select_ms[at]or-1,a[math.ceil(#a/2)],expand_ms or-1,b[math.ceil(#b/2)],b[#b])
  at=at+1;times={};frames=0
  if not pages[at] or at>12 then
   profile.stop()
   local top={};for s,n in pairs(samples)do top[#top+1]={s,n}end;table.sort(top,function(a,b)return a[2]>b[2]end)
   print('frame times:\n  '..table.concat(report,'\n  '))
   assert(worst<=120,'a vehicle page redraw took '..worst..' ms (budget 120 ms)')
   print('PASS: vehicle page redraw within budget (worst median '..worst..' ms)')
   print('hottest stacks ('..total..' samples):')
   for k=1,math.min(25,#top)do print(string.format('  %5d  %s',top[k][2],top[k][1]))end
   return false
  end
  local t0=ms();e.select(pages[at]);select_ms[at]=ms()-t0;last=ms()
 end
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
]==]
assert(loadstring(prefix..checks,'@vehicle_perf_host'))()
