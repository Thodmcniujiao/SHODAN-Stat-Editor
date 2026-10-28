local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
local checks=[==[
local J=require('json_data');local catalog=assert(state.component_catalog())
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
state.nav_open('components',12);state.component_filter('all',true);E.ui.search.text=''
assert(#E.weapons_in('HealthComponents')==total)
E.click('component_missing');assert(not E.settings.component_show_missing)
assert(#E.weapons_in('HealthComponents')==health_count)
E.click('component_missing');assert(E.settings.component_show_missing)
local alpha=catalog.by_entity.health.EF79CD8BB654397DF
assert(alpha and alpha.has_component)
E.select_weapon(alpha);E.ui.search.text='F79CD8BB654397DF';state.nav_open('components',13)
assert(E.ui.tab=='DemolitionComponents'and E.ui.weapon.entity_id==alpha.entity_id)
assert(E.ui.search.text=='F79CD8BB654397DF','switching component must preserve search')
state.nav_open('components',12);assert(E.ui.weapon==alpha)
-- The native demolition controls use exactly the existing canonical backend.
E.ui.search.text='';state.nav_open('components',13)
local gun=assert(catalog.by_entity.demolition.EEF85D6CF58E31D70)
E.select_weapon(gun);local normal=assert(gun.by_id['0:normal'])
E.change(normal.row,0,false,91)
assert(panel.values.EEF85D6CF58E31D70['0:normal']==91)
assert(E.row_value(E.by_hash.EF85D6CF58E31D70.by_id.unit_demolition.row)==91)
assert(#H.diff()==0,'native demolition UI must not write shared raw fields')
assert(panel:set('EEF85D6CF58E31D70','0:normal',20))
-- Reloaded naming/categories affect both component pages, while ids and original enemy names stay stable.
local original_json=read(catalog.path);local cfg=J.decode(original_json)
cfg.categories[#cfg.categories+1]={id='custom',name={en='Custom group',['zh-Hans']='自定义分类'},order=1}
table.insert(cfg.rules,1,{category='custom',component='HealthComponentData'})
cfg.entities.F79CD8BB654397DF={name={en='Renamed Alpha',['zh-Hans']='自定义阿尔法'},category='other'}
write(catalog.path,J.encode(cfg));state.component_reload()
assert(not catalog.config_error)
assert(catalog.by_entity.health.EF79CD8BB654397DF.name=='Renamed Alpha')
assert(catalog.by_entity.demolition.EF79CD8BB654397DF.name=='Renamed Alpha')
assert(catalog.by_entity.health.EF79CD8BB654397DF.category=='other','explicit entity entry must beat rules')
assert(catalog.by_entity.health.EEF85D6CF58E31D70.category=='custom','component rule did not match')
assert(E.by_hash.F79CD8BB654397DF.name=='Alpha Commander','JSON metadata must not rename the original enemy editor')
state.nav_open('components',12);state.component_filter('other',true);E.ui.search.text='Renamed Alpha'
assert(#E.weapons_in('?search')==1)
write(catalog.path,'{"version":');state.component_reload()
assert(catalog.config_error and alpha.name=='Renamed Alpha','invalid JSON must preserve last valid metadata')
assert(#H.diff()==0 and panel.values.EEF85D6CF58E31D70['0:normal']==20)
write(catalog.path,original_json);state.component_reload();assert(not catalog.config_error)
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
state.nav_open('components',12);E.ui.search.text='EF85D6CF58E31D70';E.select_weapon(catalog.by_entity.health.EEF85D6CF58E31D70)
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
local positions={}
for _,r in ipairs(E.ui.regions)do if r.key=='component_missing'or r.key=='component_reload'or r.key=='search'then positions[r.key]={r.x,r.y,r.w,r.h}end end
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-health.bmp')
state.nav_open('components',13);E.tick();assert(state.ui_errors==0)
for _,r in ipairs(E.ui.regions)do local p=positions[r.key];if p then
 assert(p[1]==r.x and p[2]==r.y and p[3]==r.w and p[4]==r.h,'component UI controls moved on tab switch')
end end
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-demolition.bmp')
state.nav_open('components',12);E.ui.search.text=missing.entity_hash;E.select_weapon(missing);E.tick()
assert(state.ui_errors==0 and E.ui.weapon.component_unavailable)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/browser-missing.bmp')
gdi.DeleteDC(S.dc)
print('PASS: '..total..' complete catalog entries, '..health_count..' Health / '..demolition_count..' destruction mappings; identical native UI, missing-component filter, preserved selection/search, JSON rules/overrides/reload/recovery, export index and canonical writes; no game writes')
]==]
assert(loadstring(start..checks,'@component-browser-integration'))()
