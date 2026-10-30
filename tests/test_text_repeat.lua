-- Drive the real keyboard handlers with a controlled clock and key state.
local f=assert(io.open(TEST_ROOT..'/src/stat_editor_offline.lua','rb'));local source=f:read('*a');f:close()
local function block(marker)
 local at=assert(source:find(marker,1,true));local last=assert(source:find('\nend',at,true))+3
 return source:sub(at,last)
end
local factory=assert(loadstring('return function(ui,MOD,presets,key_down,VK,typed_chars)\nlocal held={}\n'..
 block('local function pressed(name, now')..'\n'..block('local function keyboard(now)')..'\nreturn keyboard end'))()
local ui={version=0,record_id={active=false}};local down={};local edits=0
local keyboard=factory(ui,{code={MAX=9}},{type_char=function()edits=edits+1 end},
 function(k)return down[k]end,{Backspace=8,Enter=13,Escape=27,Up=38,Right=39,Down=40,Left=37},function()return{}end)
ui.rename={field='desc',text='甲乙😀中'};down[8]=true
keyboard(0);assert(ui.rename.text=='甲乙😀')
keyboard(.299);assert(ui.rename.text=='甲乙😀')
keyboard(.3);assert(ui.rename.text=='甲乙')
keyboard(.314);assert(ui.rename.text=='甲乙')
keyboard(.316);assert(ui.rename.text=='甲','fast repeat must delete whole UTF-8 characters')
down[8]=false;keyboard(.32);ui.rename=nil;ui.editing={}
down[8]=true;keyboard(1);keyboard(1.299);assert(edits==1)
keyboard(1.3);keyboard(1.316);assert(edits==3,'preset text must use fast repeat')
down[8]=false;keyboard(1.32);ui.editing=nil;ui.value={text='123456',fresh=false}
down[8]=true;keyboard(2);assert(ui.value.text=='12345')
keyboard(2.3);assert(ui.value.text=='12345','numeric edits must keep the normal delay')
keyboard(2.401);assert(ui.value.text=='1234')
keyboard(2.42);assert(ui.value.text=='1234','numeric edits must keep the normal repeat interval')
down[8]=false;keyboard(2.5);ui.value=nil;ui.code={arrows={1,2,3}}
down[8]=true;keyboard(3);assert(#ui.code.arrows==2)
keyboard(3.5);assert(#ui.code.arrows==2,'call-in code deletion must remain one arrow per key press')
print('PASS: accelerated game/preset text Backspace, complete UTF-8 deletion, normal numeric cadence and single-press call-in codes')
