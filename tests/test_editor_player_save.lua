-- Reuse the original editor harness; all profiles and writes stay isolated.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close();local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge',[[
SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model
local Save=require('player_save');local SaveIO=require('player_save_io')
local kp,kn=G.open_sealed(read(TEST_GAME..'/generated_customization_armor_sets.dl_bin'));assert(kp)
local kit=ffi.string(kp,kn);G.free(kp)
local catalog=Save.catalog(entity,kit,model.schemas,model.names)
local live_fixture=assert(os.getenv('SHODAN_PLAYER_SAVE_FIXTURE'))
local snapshot=read(live_fixture)
local savefiles={['fixture.sav']=snapshot}
SHODAN_PLAYER_SAVE_MODEL=Save.new({catalog=catalog,paths={'fixture.sav'},preset_path='presets.json',io={
 read=function(path)return savefiles[path]end,
 write=function(path,s)savefiles[path]=s;return true end,
 move=function(a,b)savefiles[b]=savefiles[a];savefiles[a]=nil;return true end,
 remove=function(path)savefiles[path]=nil end,running=function()return false end}})
]],1)
local checks=[==[
local save=SHODAN_PLAYER_SAVE_MODEL
assert(save.save,'real save did not load')
state.nav_open('armory',7)
assert(state.player_save_active(),'host save routing is not active')
local pages=E.weapons_in('CurrentLoadout');assert(#pages==4,'loadout page not exposed')
local main=pages[1];E.select_weapon(main)
local function edit(key,value)
 for i,row in ipairs(main.rows)do if row.id==key then
  E.click('value:'..i);assert(E.ui.value,'input not opened for '..key)
  E.ui.value.text=tostring(value);assert(state.commit_value(),'input not committed for '..key);return row
 end end;error('missing field '..key)
end
local current=save:read('primary');local replacement
for id in pairs(save.catalog.categories.primary)do if id~=current then replacement=id;break end end
assert(replacement)
local row=edit('primary',replacement)
assert(save:read('primary')==replacement and E.modified(main))
TEST_PRESETS_HELPER.save(E,main,1);E.reset_weapon(main);assert(save:read('primary')==current)
TEST_PRESETS_HELPER.load(E,main,1);assert(save:read('primary')==replacement)
TEST_PRESETS_HELPER.delete(E,main,1);assert(not TEST_PRESETS_HELPER.get(E,main,1))
assert(#H.diff()==0,'save edit mutated a DL table')
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.tick();S.sleep(1650);E.tick();assert(E.ui.gui,'panel never rendered')
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;E.ui.version=E.ui.version+1;S.lang=function()return lang end
 for i,p in ipairs(E.weapons_in('CurrentLoadout'))do
  E.select_weapon(p);E.tick();assert(state.ui_errors==0 and #E.ui.regions>20,'native draw failed')
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/player-save-'..i..'-'..lang..'.bmp')
 end
end
assert(savefiles['fixture.sav']==snapshot,'UI staging wrote a file')
assert(read(live_fixture)==snapshot,'live source changed')
gdi.DeleteDC(S.dc)
print('PASS: actual current editor navigation, input/commit, current item category catalog, presets/reset/clear, bilingual GDI render of four pages; no DL or live save writes')
]==]
assert(loadstring(start..checks,'@player-save-editor-integration'))()
