local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
local checks=[==[
local J=require('json_data');local catalog=assert(state.component_catalog())
local function open(tab)
 local parent,k=assert(E.MOD.nav.locate(tab));assert(parent.id=='components')
 state.nav_open(parent.id,k);E.click('cat:'..tab);assert(E.ui.tab==tab)
end
local nav=E.MOD.nav.page('components');assert(#nav.subs==8)
local mines=nav.subs[6];assert(mines.name[2]=='地雷与投掷'and #mines.tabs==4)
assert(table.concat(mines.tabs,',')=='MinefieldComponents,MineSpawnerComponents,ThrowableComponents,ThrowerComponents')
local life=nav.subs[7];assert(life.name[2]=='生命与拆毁'and #life.tabs==6)
assert(table.concat(life.tabs,',')=='HealthComponents,DemolitionComponents,DrownComponents,ShieldComponents,OverlapDamageComponents,FactionComponents')
assert(E.MOD.nav.locate('DrownComponents')and E.MOD.nav.locate('ShieldComponents')and E.MOD.nav.locate('OverlapDamageComponents'))
local orbitals=E.MOD.nav.page('orbitals');assert(orbitals.subs[2].tabs[1]=='Eagle')
assert(state.native_component_browser,'both pages must use the original GUI renderer')
local total=#catalog.records
assert(total>#model.targets,'directory must include entities without Unit/destruction mappings')
assert(#catalog.views.health==total and #catalog.views.demolition==total)
local health_count,demolition_count,missing=0,0,nil
for _,r in ipairs(catalog.records)do
 local hp,dp=catalog.by_entity.health[r.id],catalog.by_entity.demolition[r.id]
 assert(hp.entity_id==dp.entity_id)
 if hp.has_component then health_count=health_count+1 else assert(#hp.rows==0);missing=missing or hp end
 if dp.has_component then demolition_count=demolition_count+1 else assert(#dp.rows==0)end
end
assert(health_count==506 and demolition_count>1700 and missing)
open('HealthComponents');state.component_filter('all',true);E.ui.search.text=''
assert(#E.weapons_in('HealthComponents')==total)
E.click('component_missing');assert(not E.settings.component_show_missing)
assert(#E.weapons_in('HealthComponents')==health_count)
E.click('component_missing');assert(E.settings.component_show_missing)
local alpha=catalog.by_entity.health.EF79CD8BB654397DF
assert(alpha and alpha.has_component)
E.select_weapon(alpha);E.ui.search.text='F79CD8BB654397DF';open('DemolitionComponents')
assert(E.ui.tab=='DemolitionComponents'and E.ui.weapon.entity_id==alpha.entity_id)
assert(E.ui.search.text=='F79CD8BB654397DF','switching component must preserve search')
open('HealthComponents');assert(E.ui.weapon==alpha)
-- The native demolition controls use exactly the existing canonical backend.
E.ui.search.text='';open('DemolitionComponents')
local gun=assert(catalog.by_entity.demolition.EEF85D6CF58E31D70)
E.select_weapon(gun);local normal=assert(gun.by_id['0:normal'])
E.change(normal.row,0,false,91)
assert(panel.values.EEF85D6CF58E31D70['0:normal']==91)
assert(E.row_value(E.by_hash.EF85D6CF58E31D70.by_id.unit_demolition.row)==91)
assert(#H.diff()==0,'native demolition UI must not write shared raw fields')
assert(panel:set('EEF85D6CF58E31D70','0:normal',20))
-- Reloaded naming/categories affect both component pages, while ids and original enemy names stay stable.
local F=require('preset_files')
local custom_path=catalog.folder..'/custom.json'
assert(F.write(custom_path,J.encode({id='custom',group={en='Custom group',['zh-Hans']='自定义分类'},order=1,
 entities={{hash='0xF79CD8BB654397DF',name={en='Renamed Alpha',['zh-Hans']='自定义阿尔法'}}}})))
-- Move rather than duplicate the hash between group files.
local previous_path
for _,file in pairs(catalog.config.files)do
 local rows=J.array()
 for _,item in ipairs(file.data.entities)do
  if item.hash:upper()~='0XF79CD8BB654397DF'then rows[#rows+1]=item else previous_path=file.path end
 end
 file.data.entities=rows;assert(F.write(file.path,J.encode(file.data)))
end
assert(previous_path)
state.component_reload();assert(not catalog.config_error,tostring(catalog.config_error))
assert(catalog.by_entity.health.EF79CD8BB654397DF.name=='Renamed Alpha')
assert(catalog.by_entity.demolition.EF79CD8BB654397DF.name=='Renamed Alpha')
assert(catalog.by_entity.health.EF79CD8BB654397DF.category=='custom')
assert(E.by_hash.F79CD8BB654397DF.name=='Alpha Commander','JSON metadata must preserve internal enemy page names')
open('HealthComponents');state.component_filter('other',false);E.ui.search.text='Renamed Alpha'
assert(#E.weapons_in('?search')==1,'hash search must span all groups')
E.ui.search.text='17842374123104475103';assert(#E.weapons_in('?search')==1,'exact decimal hash missing')
E.ui.search.text='0xf79cd8bb654397df';assert(#E.weapons_in('?search')==1,'prefixed hex missing')
assert(E.MOD.record_names.jump('HealthComponents','17842374123104475103')==alpha)
assert(E.MOD.record_names.jump('HealthComponents','0xf79cd8bb654397df')==alpha)
assert(F.write(custom_path,'{"version":'));state.component_reload()
assert(catalog.config_error and alpha.name=='Renamed Alpha','invalid JSON must preserve last valid metadata')
assert(#H.diff()==0 and panel.values.EEF85D6CF58E31D70['0:normal']==20)
assert(F.write(custom_path,J.encode({id='custom',group='Custom group',entities={{hash='0xF79CD8BB654397DF',name='Renamed Alpha'}}})))
state.component_reload();assert(not catalog.config_error)
local index=J.decode(read(catalog.path:gsub('%.json$','.index.json')));assert(#index.entities==total)
-- Persist and restore the visibility preference without changing component presence.
E.settings.component_show_missing=false;assert(E.save_config())
assert(read(I.home..'/config.txt'):find('component_show_missing off',1,true))
state.component_filter('all',true)
-- Render the same entity in both pages and verify identical sidebar/filter controls.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
open('HealthComponents');E.ui.search.text='EF85D6CF58E31D70';E.select_weapon(catalog.by_entity.health.EEF85D6CF58E31D70)
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
local positions={}
for _,r in ipairs(E.ui.regions)do if r.key=='component_missing'or r.key=='component_reload'or r.key=='search'then positions[r.key]={r.x,r.y,r.w,r.h}end end
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-health.bmp')
open('DemolitionComponents');E.tick();assert(state.ui_errors==0)
for _,r in ipairs(E.ui.regions)do local p=positions[r.key];if p then
 assert(p[1]==r.x and p[2]==r.y and p[3]==r.w and p[4]==r.h,'component UI controls moved on tab switch')
end end
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-demolition.bmp')
open('HealthComponents');E.ui.search.text=missing.entity_hash;E.select_weapon(missing);E.tick()
assert(state.ui_errors==0 and E.ui.weapon.component_unavailable)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-missing.bmp')
-- The merged group exposes all four component buttons in the title row.
E.ui.search.text='';state.component_filter('all',false)
for _,tab in ipairs(mines.tabs)do
 open(tab);E.tick();assert(state.ui_errors==0)
 local buttons={};for _,r in ipairs(E.ui.regions)do buttons[r.key]=r end
 for _,expected in ipairs(mines.tabs)do assert(buttons['cat:'..expected],expected..' title button missing')end
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/merged-'..tab..'.bmp')
end
assert(#H.diff()==0)
gdi.DeleteDC(S.dc)
print('PASS: '..total..' complete catalog entries, '..health_count..' Health / '..demolition_count..' destruction mappings; native controls, cross-group exact hash/decimal search/jump, JSON groups/reload/recovery, export index and canonical writes; no game writes')
]==]
assert(loadstring(start..checks,'@component-browser-integration'))()
