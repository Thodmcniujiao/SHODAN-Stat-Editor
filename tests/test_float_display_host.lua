-- Use the production host with isolated portable data and read-only live game files.
local file=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(file:read('*a'):match('^(.-)local phase, changed, began'));file:close()
local checks=[==[
local began=tonumber(ffi.C.GetTickCount64());local phase,changed=0,0
local page,rows
local function now()return tonumber(ffi.C.GetTickCount64())end
local function index(e,row)
 for n,r in ipairs(page.rows)do if r==row then return n end end
 error('numeric row is not visible')
end
S.pump=function()
 assert(now()-began<90000,'float display host timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   local e=assert(TEST_PARAMETERS)
   local group
   for _,w in ipairs(e.weapons)do
    for _,g in ipairs(w.component_groups or{})do
     if g.type=='WeaponDataComponentData'then page,group=w,g;break end
    end
    if page then break end
   end
   assert(page and group,'missing native weapon data component')
   e.select(page);e.click('comp_toggle:'..group.type);e.MOD.parameter_refresh(page);e.MOD.nav.sync()
   rows={}
   for _,r in ipairs(group.rows)do
    if r.storage=='f32'and #r.parts==1 and r.parts[1].field.storage=='f32'and not(r.choice or r.mult or r.span or r.scale)then
     rows[#rows+1]=r;if #rows==3 then break end
    end
   end
   assert(#rows==3)
   local first=rows[1]
   e.change(first,0,false,200.20001220703125)
   assert(e.format(e.row_value(first),'f32')=='200.2')
   local before=e.row_value(first);local writes=state.writes
   e.click('value:'..index(e,first));assert(e.ui.value.text=='200.2'and e.ui.value.fresh)
   assert(state.commit_value()and not e.ui.value)
   assert(e.row_value(first)==before and state.writes==writes,'confirming clean input changed stored float bits')
   assert(e.MOD.clipboard.row_text(first)=='200.2','clipboard exposed binary residue')
   local small=first.small;first.small=.1
   e.change(first,0,false,200);e.change(first,1,false);e.change(first,1,false)
   assert(e.row_value(first)==e.MOD.numeric.validate({storage='f32'},200.2),'actual increment accumulated residue')
   e.change(first,-1,false);e.change(first,-1,false);assert(e.row_value(first)==200)
   first.small=small
   e.click('value:'..index(e,first));e.ui.value.text='1e-30';e.ui.value.fresh=false
   assert(state.commit_value()and e.row_value(first)~=0 and e.format(e.row_value(first),'f32')=='1e-30')
   local tiny=e.row_value(first);e.click('value:'..index(e,first));assert(e.ui.value.text=='1e-30')
   assert(state.commit_value()and e.row_value(first)==tiny,'clean tiny input lost precision')
   e.change(first,0,false,200.20001220703125)
   e.change(rows[2],0,false,450.3000183105469);e.change(rows[3],0,false,0.10000000149011612)
   assert(e.format(e.row_value(rows[2]),'f32')=='450.3'and e.format(e.row_value(rows[3]),'f32')=='0.1')
   assert(e.save())
   local p=first.parts[1];local owner=p.health_owner or{weapon=page,part=p}
   local lead=owner.weapon.hash..' '..owner.part.id..' ';local saved
   for line in assert(I.read(I.home..'/config.txt')):gmatch('[^\r\n]+')do
    if line:sub(1,#lead)==lead then saved=tonumber(line:sub(#lead+1):match('^%S+'))end
   end
   assert(saved==e.row_value(first),'display cleanup rounded the saved value')
   local tree=require('preset_details').build({values={{hash=owner.weapon.hash,id=owner.part.id,value=saved}},data={}},{
    by_hash=e.by_hash,lang=function()return'zh-Hans'end,tr=e.settings.tr,navigation=e.MOD.nav.PAGES,
    tab_of=e.MOD.nav.tab_of,default_value=state.vanilla})
   local found=false
   for _,p in ipairs(tree)do for _,s in ipairs(p.sections)do for _,r in ipairs(s.rows)do
    if r.id==owner.part.id and r.value=='200.2'then found=true end
   end end end
   assert(found,'preset preview did not use the cleaned float format')
   e.ui.scroll,e.ui.row=index(e,first),index(e,first);phase,changed=1,now()
  end
  if phase==1 and now()-changed>180 then S.version=S.version+1 end
 end
 return phase<2
end
S.present=function()
 local state=rawget(_G,'ShodanStatEditor')
 if phase==1 and state and state.phase=='ready'and now()-changed>1900 then
  assert(state.ui_errors==0,'float rendering failed')
  S.save_bmp(TEST_WORK..'/float-clean-display.bmp')
  local e=assert(TEST_PARAMETERS)
  for _,r in ipairs(rows)do e.reset_row(page,r)end
  e.MOD.enemy.faction_refresh()
  assert(#H.diff()==0,'float display test left native values changed')
  phase=2
 end
end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and app..'/host.lua'or TEST_ROOT..'/offline/host.lua'))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS: actual float display/input/clipboard/preview, decimal increment/decrement, unchanged confirmation, exact saved values, tiny floats; no game writes')
]==]
assert(loadstring(prefix..checks,'@float-display-host'))()
