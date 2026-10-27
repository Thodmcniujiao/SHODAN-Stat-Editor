local D=require('demolition');local P=require('demolition_panel');local I=require('install')
local function r(n)local f=assert(io.open(TEST_FIXTURES..'/'..n,'rb'));local s=f:read('*a');f:close();return s end
local m=D.new(r('generated_entities.dl_bin'),r('generated_destruction_settings.dl_bin'),r('dl_library.dl_typelib'))
I.mkdirs(TEST_WORK)
local path=TEST_WORK..'/entity_demolition.txt';local changes=0
local p=P.new(m,{path=path,lang=function()return'zh-Hans'end,changed=function()changes=changes+1 end})
local id='EEF85D6CF58E31D70'
assert(p:set(id,'0:normal',999))
assert(p.values[id]['0:normal']==999)
assert(not p:set(id,'0:normal',0/0))
assert(p.values[id]['0:normal']==999)
local reload=P.new(m,{path=path})
assert(reload.values[id]['0:normal']==999 and not next(reload:overrides(false)))
assert(reload:set(id,'0:normal',m.by_id[id].levels[1].value))
assert(reload.values[id],'entering the baseline explicitly must still create an independent override')
assert(reload:set(id,'0:normal',nil)and not reload.values[id])
assert(changes==1)
p.filter='EF85D6CF58E31D70';p:refilter();assert(#p.list==1 and p.list[1].id==id)
local capture={};local shim={h=1080,w=1060,fill=function()end,flush=function()end,
 text_width=function(s,size)return #s*size*.5 end,text_height=function(size)return size*1.2 end,
 text_top=function(s,x,y,size)capture[#capture+1]={s=s,x=x,y=y,size=size}end}
p:draw(shim);assert(#capture>15 and #p.hits>10)
-- Every button caption must fit inside its clickable rectangle, including the reset buttons.
for _,hit in ipairs(p.hits)do
 if hit.action=='mode'or hit.action=='page'or hit.action:find('reset')then
  local inside=false
  for _,label in ipairs(capture)do
   if label.x>=hit.x and label.y>=hit.y and label.x+#label.s*label.size*.5<=hit.x+hit.w+.01
    and label.y+label.size*1.2<=hit.y+hit.h then inside=true;break end
  end
  assert(inside,'caption outside button: '..hit.action)
 end
end
local q=P.new(m,{path=TEST_WORK..'/input.txt'})
local keys,typed,mouse={},'',{40,140}
shim.focused=function()return true end
shim.key_down=function(vk)return keys[vk]or false end
shim.cursor=function()return mouse[1],mouse[2]end
shim.take_typed=function()local s=typed;typed='';return s end
local function tick(text,down)typed=text or'';keys=down or{};q:update(shim)end
local function press(vk)tick('',{[vk]=true});tick()end
local function click(action)
 q:draw(shim)
 for _,hit in ipairs(q.hits)do if hit.action==action then
  mouse={hit.x+hit.w/2,hit.y+hit.h/2};press(1);return
 end end
 error('missing clickable control '..action)
end
q:activate(shim);tick('gatling');assert(q.filter=='gatling')
tick('炮台');assert(q.filter=='gatling炮台')
press(8);assert(q.filter=='gatling炮');press(8);assert(q.filter=='gatling')
q.filter='';q:refilter();tick('EF85D6CF58E31D70')
assert(#q.list==1 and q.list[1].id==id)
press(13);assert(q.focus=='search'and not next(q.values),'search Enter must not edit a threshold')
click('select');assert(q.focus==nil)
local version=q.version;click('search');assert(q.focus=='search'and q.version>version)
q:edit(1);tick('1234');assert(q.buffer=='1234');press(8);assert(q.buffer=='123')
press(13);assert(q.values[id]['0:normal']==123 and q.focus==nil)
tick('',{[0x11]=true,[0x46]=true});tick();assert(q.focus=='search')
q.focus=nil;tick();tick('',{[0x11]=true,[0x46]=true});tick()
assert(q.focus=='search','Ctrl+F must work repeatedly')
q:edit(1);press(0x2E);assert(q.buffer==''and q.values[id]['0:normal']==123)
print('PASS: persistence, search typing (Latin/Chinese/hash), UTF-8 backspace, click focus, Ctrl+F, Enter, numeric edit and button bounds')
