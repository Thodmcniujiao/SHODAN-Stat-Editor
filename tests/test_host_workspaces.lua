-- Run the production desktop host offscreen, including its bottom action bar.
-- Uses an isolated LOCALAPPDATA. Live game/save files are read only.
local ffi=require('ffi');local I=require('install');local S=require('engine_shim')
I.mkdirs(TEST_WORK);I.mkdirs(I.home)
SHODAN_PRESET_DIRECTORY=TEST_WORK..'/program/Presets'
local function write(path,text)local f=assert(io.open(path,'wb'));assert(f:write(text));f:close()end
write(I.home..'/game folder.txt',TEST_GAME)
write(I.home..'/preset_01.txt','name 示例预设\nEF85D6CF58E31D70 unit_demolition 222\n')
S.w,S.h=1272,1296
local gdi=ffi.load('gdi32');S.dc=gdi.CreateCompatibleDC(nil);assert(S.dc~=nil)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
S.open=function()end;S.set_title=function(title)S.title=title end
S.focused=function()return false end;S.cursor=function()return nil,nil end
S.message_box=function(message)error(message,0)end
local phase,changed=0,0;local began=tonumber(ffi.C.GetTickCount64())
-- Expose the real control handlers only inside this test process.
local panel=TEST_ROOT..'/src/stat_editor_offline.lua';local real_loadfile=loadfile
loadfile=function(path,...)
 if path==panel then
  local f=assert(io.open(path,'rb'));local source=f:read('*a');f:close()
  return loadstring(source..'\nTEST_HOST_SETTINGS={ui=ui,click=click,settings=settings,save=save_config,nav=MOD.nav}\n','@'..path)
 end
 return real_loadfile(path,...)
end
local function now()return tonumber(ffi.C.GetTickCount64())end
S.pump=function()
 assert(now()-began<90000,'host smoke timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then assert(state.open_workspace('presets'));phase=1;changed=now()end
  if phase>0 and phase<4 and now()-changed>(phase==1 and 1900 or 150)then S.version=S.version+1 end
 end
 return phase<4
end
S.present=function()
 local state=rawget(_G,'ShodanStatEditor');if not state or state.phase~='ready'then return end
 if phase==1 and now()-changed>1900 then
  assert(state.workspace_mode()=='presets'and state.ui_errors==0)
  S.save_bmp(TEST_WORK..'/host-presets.bmp');assert(state.open_workspace('settings'));phase=2;changed=now()
 elseif phase==2 and now()-changed>150 then
  assert(state.workspace_mode()=='settings'and state.ui_errors==0)
  local e=assert(TEST_HOST_SETTINGS)
  local function region(key)
   for _,r in ipairs(e.ui.regions)do if r.key==key then return r end end
   error('missing settings control: '..key)
  end
  local font,res=region('value:font_px'),region('value:render_height')
  assert(font.y==res.y and font.x+font.w<res.x,'display fields must share a row without overlap')
  assert(region('link:log_open').y>region('game_launch').y+region('game_launch').h,'settings overflow into footer')
  local misc=e.nav.page('misc');assert(#misc.subs==4)
  for _,sub in ipairs(misc.subs)do assert(sub.name[1]~='Editor settings'and not sub.display,'old settings sub-page remains')end
  e.click('value:font_px');assert(e.ui.value and e.ui.value.setting=='font_px')
  e.ui.value.text='19';assert(state.commit_value());assert(e.settings.font_px==19 and S.display.font==19/16)
  e.click('set:font_px:up');assert(e.settings.font_px==20)
  e.click('set:font_px:down');assert(e.settings.font_px==19)
  e.click('value:render_height');e.ui.value.text='2176x2160';assert(state.commit_value())
  assert(e.settings.render_height==2160 and S.display.height==2160)
  assert(e.save());local cfg=assert(I.read(I.home..'/config.txt'))
  assert(cfg:find('font_px 19',1,true)and cfg:find('render_height 2160',1,true),'display settings were not saved')
  e.click('set:render_height:up');assert(e.settings.render_height==2220)
  e.click('set:render_height:down');assert(e.settings.render_height==2160)
  e.click('set:font_px:reset');e.click('set:render_height:auto')
  assert(e.settings.font_px==16 and e.settings.render_height==0 and S.display.font==1 and S.display.height==0)
  assert(e.save())
  S.save_bmp(TEST_WORK..'/host-settings.bmp');assert(state.open_workspace('editor'));phase=3;changed=now()
 elseif phase==3 and now()-changed>150 then
  assert(state.workspace_mode()=='editor'and state.ui_errors==0)
  S.save_bmp(TEST_WORK..'/host-editor.bmp');phase=4
 end
end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(TEST_ROOT..'/offline/host.lua'))()
assert(phase==4,'host failed before all modes were rendered')
loadfile=real_loadfile
-- the title: this fork's release and who it is by, then when it was packed (no panel version, no upstream dev commit)
-- (only the package has app/build.txt, so the build stamp is checked after packing: build_release.ps1)
assert(S.title:find('SHODAN Stat Editor Offline 0.0.8 Reorganized by Thodmc',1,true),S.title)
assert(not S.title:find('4.5.1',1,true) and not S.title:find('dev ',1,true) and not S.title:find('|',1,true),S.title)
gdi.DeleteDC(S.dc)
print('PASS: host workspaces, moved display controls/input/apply/reset/config, no editor-settings sub-page, visible footer links, original editor restores; isolated profile and no live writes')
