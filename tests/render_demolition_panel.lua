-- Render the real GDI back buffer without opening or focusing any desktop window.
local ffi=require('ffi');local S=require('engine_shim');local D=require('demolition');local P=require('demolition_panel')
local I=require('install');I.mkdirs(TEST_WORK)
local function read(n)local f=assert(io.open(TEST_FIXTURES..'/'..n,'rb'));local s=f:read('*a');f:close();return s end
local m=D.new(read('generated_entities.dl_bin'),read('generated_destruction_settings.dl_bin'),read('dl_library.dl_typelib'))
local gdi=ffi.load('gdi32');S.dc=gdi.CreateCompatibleDC(nil);assert(S.dc~=nil)
local function render(lang,height)
 S.lang=function()return lang end
 S.h=height;S.w=math.floor(height*1060/1080+.5)
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
 info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
 local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
 local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0])
 gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 local p=P.new(m,{path=TEST_WORK..'/unused.txt',lang=S.lang})
 for i,t in ipairs(p.list)do if t.hash=='709C4B26A4E15BD5'then p.selected=i;p.scroll=math.max(0,i-6);break end end
 p.hover='reset:1';p:draw(S)
 S.save_bmp(TEST_WORK..'/demolition-'..lang..'-'..height..'.bmp')
 -- TextOutW uses a baseline; the top-aligned helper must render an entire glyph inside this box.
 local scale=height/1080;local x0,y0=math.floor(30*scale+.5),math.floor(128*scale+.5)
 local x1,y1=math.floor(1030*scale+.5),math.floor(164*scale+.5)
 assert(tonumber(S.bits[y0*S.w+x0])==0x67D2DC,'focused search border missing')
 assert(y1-y0>S.text_height(17*scale),'search font too tall for its clickable input')
 gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib)
end
render('en',1080);render('zh-Hans',1080);render('en',1350);render('zh-Hans',1350)
-- Exercise the same WM_CHAR pump as the app, on this test thread, without injecting input into other apps.
ffi.cdef('int PostThreadMessageW(uint32_t thread, uint32_t msg, uintptr_t wparam, intptr_t lparam); uint32_t GetCurrentThreadId(void);')
local user=ffi.load('user32');local kernel=ffi.load('kernel32')
S.pump() -- creates this thread's message queue
for _,code in ipairs({71,97,116,108,105,110,103,32,0x70AE,0x53F0,57,57,57})do
 assert(user.PostThreadMessageW(kernel.GetCurrentThreadId(),0x0102,code,0)~=0)
end
S.pump()
local input=P.new(m,{path=TEST_WORK..'/input-unused.txt'})
S.focused=function()return true end;S.key_down=function()return false end;S.cursor=function()return nil end
input:update(S);assert(input.filter=='Gatling 炮台999','WM_CHAR must reach the actual search controller')
assert(S.take_typed()=='','typed characters must be consumed once')
gdi.DeleteDC(S.dc)
print('PASS: actual GDI rendering at two scales in English/Chinese; Windows WM_CHAR queue (Latin/Chinese/digits)')
