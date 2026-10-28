-- Run the production desktop host offscreen, including its bottom action bar.
-- Uses an isolated LOCALAPPDATA. Live game/save files are read only.
local ffi=require('ffi');local I=require('install');local S=require('engine_shim')
I.mkdirs(TEST_WORK);I.mkdirs(I.home)
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
  S.save_bmp(TEST_WORK..'/host-settings.bmp');assert(state.open_workspace('editor'));phase=3;changed=now()
 elseif phase==3 and now()-changed>150 then
  assert(state.workspace_mode()=='editor'and state.ui_errors==0)
  S.save_bmp(TEST_WORK..'/host-editor.bmp');phase=4
 end
end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=TEST_ROOT..'/src/stat_editor_offline.lua'}
assert(loadfile(TEST_ROOT..'/offline/host.lua'))()
assert(phase==4,'host failed before all modes were rendered')
assert(S.title:find('v4.1.0',1,true))
gdi.DeleteDC(S.dc)
print('PASS: production host starts with current game tables, all four footer actions render, preset/settings hide original tabs, original editor restores; isolated profile and no live writes')
