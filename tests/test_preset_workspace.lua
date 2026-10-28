-- Real editor integration, isolated profile, offscreen native GDI rendering.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'));local text=f:read('*a');f:close()
local start=assert(text:match('^(.-)local weapon=assert'))
start=start:gsub('local state\n',[[
write(I.home..'/preset_01.txt','name Existing full\n'..hash..' unit_demolition 321\n')
write(I.home..'/weapon_presets.txt',hash..' 5 unit_demolition 456\n')
local state
]],1)
local checks=[==[
local weapon=assert(E.by_hash[hash]);local normal=assert(weapon.by_id.unit_demolition)
assert(not E.presets.weapon_count and not E.presets.save_weapon_preset,'old quick preset API still exposed')
local library=E.presets.library;assert(library)
local old_full,old_single
for _,p in ipairs(library:list('game'))do if p.name=='Existing full'then old_full=p elseif p.kind=='patch'then old_single=p end end
assert(old_full and old_single,'legacy files were not imported')
E.select_weapon(weapon);E.ui.page=3;E.ui.row=2;E.ui.scroll=2;E.ui.search.text='retained search'
local tab,page=E.ui.tab,E.ui.nav.page
local row_index;for i,r in ipairs(weapon.rows)do if r==normal.row then row_index=i end end;assert(row_index)
E.ui.value={weapon=weapon,n=row_index,text='bad input'}
assert(not state.open_workspace('presets')and state.workspace_mode()=='editor','invalid field was discarded')
E.ui.value={weapon=weapon,n=row_index,text='777'}
assert(state.open_workspace('presets')and state.workspace_mode()=='presets')
assert(E.row_value(normal.row)==777,'pending value not committed')
local new_id=assert(E.presets.new_full_preset());assert(E.ui.editing)
E.ui.editing.text='命名方案';assert(E.presets.finish_rename(true));assert(library:get(new_id).name=='命名方案')
E.change(normal.row,0,false,999)
assert(E.presets.load_full_preset(new_id));assert(E.row_value(normal.row)==777,'named snapshot failed to load')
assert(E.presets.load_full_preset(old_single.id));assert(E.row_value(normal.row)==456,'legacy partial preset failed')
assert(state.open_workspace('settings')and state.workspace_mode()=='settings')
assert(state.open_workspace('editor')and state.workspace_mode()=='editor')
assert(E.ui.tab==tab and E.ui.nav.page==page and E.ui.weapon==weapon and E.ui.page==3 and E.ui.scroll==2 and E.ui.search.text=='retained search','editor context not restored')
local Stage={snapshot=function()return{version=0x107,values={primary=123}}end,apply_snapshot=function(self,data)self.loaded=data;return true end}
SHODAN_PLAYER_SAVE_MODEL=Stage
local Preload={snapshot=function()return{version=1,selected={A=true},targets={},edits={},arrays={}}end,apply_snapshot=function(self,data)self.loaded=data;return true end}
SHODAN_PRELOAD_MODEL=Preload
assert(state.open_workspace('presets'));assert(E.presets.select_scope('loadout'))
local save_id=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false));assert(E.presets.load_full_preset(save_id));assert(Stage.loaded.values.primary==123)
assert(E.presets.select_scope('preload'));local preload_id=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false));assert(E.presets.load_full_preset(preload_id));assert(Preload.loaded.selected.A)
assert(E.presets.select_scope('game'));E.presets.show(new_id)
local function render(lang,w,h,mode,suffix)
 E.settings.lang=lang;S.lang=function()return lang end;S.w,S.h=w,h;E.ui.version=E.ui.version+1
 if state.workspace_mode()~=mode then assert(state.open_workspace(mode))end
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=w,-h,1,32
 local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
 local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0 and E.ui.gui,'native workspace draw failed')
 local seen={};for _,region in ipairs(E.ui.regions)do
  seen[region.key]=true
  assert(not region.key:match('^wslot:')and not region.key:match('^wpreset:'),'quick preset controls survived')
  if mode=='presets'or mode=='settings'then
   assert(not region.key:match('^nav:')and not region.key:match('^cat:')and region.key~='reset_weapon','original page navigation leaked into workspace')
   assert(not region.key:match('^weapon:'),'background weapon list leaked into workspace')
  end
  if mode=='editor'then assert(region.key~='presets'and region.key~='settings','duplicate footer buttons survived')end
 end
 if mode=='presets'then assert(seen['fpreset:new']and seen['workspace_back']and seen['preset_scope:loadout'])end
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..mode..'-'..suffix..'.bmp')
 gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib)
end
render('zh-Hans',1060,1080,'presets','zh')
render('en',1060,1080,'presets','en')
render('zh-Hans',3650,806,'presets','wide')
render('zh-Hans',1060,1080,'settings','zh')
render('zh-Hans',1060,1080,'editor','zh')
assert(library:get(new_id),'preset disappeared after returning')
assert(#H.diff()==0,'preset UI modified shared DL data instead of canonical values')
gdi.DeleteDC(S.dc)
print('PASS: real editor named presets; legacy import/application; input guard; resource/custom scopes; preserved return context; no quick slots/APIs; independent preset/settings regions; Chinese/English/ultrawide native renders; no game writes')
]==]
assert(loadstring(start..checks,'@preset-workspace-integration'))()
