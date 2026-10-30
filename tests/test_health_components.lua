-- Reuse the authenticated-data/editor startup of the demolition integration test.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'), 'editor startup fixture changed')
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
local checks=[==[
local health=assert(state.health_components());assert(#health.pages>100)
-- 人物数据: Avatar, Health and Faction, then (where the game has them) danger sense, melee strikes and every weapon's
-- sway, each a collapsed component (the Armory's component view)
local player=assert(E.weapons_in('Helldiver')[1],'helldiver page missing')
assert(player.player and player.component_groups and #player.component_groups>=3)
assert(player.component_groups[1].type=='AvatarComponentData'and player.component_groups[2].type=='HealthComponentData')
assert(#player.rows==#player.component_groups and player.rows[1].collapsed_component)
E.ui.expanded_components[player.hash..':AvatarComponentData']=true
player.sync_rows('AvatarComponentData')
assert(#player.rows>100)
local enemy=assert(E.by_hash.F79CD8BB654397DF,'Alpha Commander missing')
local page=assert(health.by_entity.F79CD8BB654397DF,'Alpha Commander Health view missing')
page.ensure_rows()
assert(page.by_id.health.field==enemy.by_id.health.field,'both pages must reuse the identical field')
local kind=enemy.by_id.health.field.kind
for _,view in ipairs(health.pages)do for _,row in ipairs(view.rows)do for _,p in ipairs(row.parts)do
 assert(p.field.kind==kind,'a non-Health component leaked into the Health page')
end end end
local zone_count=0
for id,p in pairs(enemy.by_id)do
 if id:match('^zone%d+_')and not id:match('_%d+$')then
  local q=assert(page.by_id[id],'body part field missing: '..id)
  assert(q.field==p.field,'body part has a duplicate backend: '..id);zone_count=zone_count+1
 end
end
assert(zone_count>=30,'expected face, legs and claws')
local base=E.row_value(enemy.by_id.health.row,true)
E.ui.weapon=page;E.change(page.by_id.health.row,0,false,12345)
assert(E.row_value(enemy.by_id.health.row)==12345)
assert(E.modified(page)and E.modified(enemy))
local seen=0
for _,o in ipairs(E.overrides())do if o.id=='health'and o.hash==enemy.hash then seen=seen+1 end end
assert(seen==1,'Health edits must have one canonical saved owner')
local face=assert(enemy.by_id.zone0_health)
E.ui.weapon=enemy;E.change(face.row,0,false,314)
assert(E.row_value(page.by_id.zone0_health.row)==314,'enemy -> Health component must synchronize')
E.ui.weapon=page;E.reset_row(page,page.by_id.health.row)
assert(E.row_value(enemy.by_id.health.row)==base)
E.reset_row(page,page.by_id.zone0_health.row)
-- A Health record that had no original enemy/weapon page must also be editable and saveable.
local unknown
for _,view in ipairs(health.pages)do
 local p=view.by_id.health;if p and not p.health_owner then unknown=view;break end
end
assert(unknown,'expected an entity beyond the original catalog')
unknown.ensure_rows()
E.ui.weapon=unknown;local p=unknown.by_id.health;local original_value=E.row_value(p.row)
E.change(p.row,0,false,original_value+10);assert(E.row_value(p.row)==original_value+10)
assert(E.save_config());assert(read(I.home..'/config.txt'):find(unknown.hash..' health ',1,true))
E.reset_row(unknown,p.row)
local function open(tab)
 local parent,k=assert(E.MOD.nav.locate(tab));state.nav_open(parent.id,k);E.click('cat:'..tab)
 assert(E.ui.tab==tab)
end
open('HealthComponents');assert(not state.component_view())
E.ui.search.text='F79CD8BB654397DF';local results=E.weapons_in('?search');assert(#results==1 and results[1]==page)
open('DemolitionComponents');assert(state.component_view()=='demolition')
local tabs=state.component_tabs();assert(#tabs==8 and tabs[7].label=='Health and demolition'and tabs[7].selected)
E.click('cat:HealthComponents')
assert(E.ui.tab=='HealthComponents'and not state.component_view(),'demolition -> Health navigation failed')
state.nav_open('enemies',1)
assert(enemy.by_id.health and enemy.by_id.zone0_health,'original enemy settings were removed')
assert(#H.diff()==0,'reset Health edits must restore the original data bytes')
-- Health-only installs also use the bounded unused-record hash correction, without requiring a demolition override.
assert(bridge:clear());E.ui.weapon=page;E.change(page.by_id.health.row,0,false,2001)
local changes=H.diff();assert(#changes==1 and changes[1].name=='generated_entities.dl_bin')
changes[1].demolition_schemas=model.schemas
local sealed,why=H.build(changes[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==changes[1].hash)
local found=false
for _,header in ipairs(G.headers(plain,n))do if header.type==kind then
 assert(D.u32(ffi.string(plain,n),header.at+24+page.health_offset)==2001);found=true
end end
G.free(plain);assert(found,'installed Health record not found');E.reset_row(page,page.by_id.health.row)
assert(#H.diff()==0)
-- Render both sibling pages through the actual GDI renderer, without opening a window.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
open('HealthComponents');E.ui.search.text='Alpha Commander';E.select_weapon(page);E.tick();S.sleep(1700);E.tick()
assert(state.ui_errors==0,'Health view failed to render')
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/health-zh-Hans.bmp')
open('DemolitionComponents');E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19})
S.save_bmp(TEST_WORK..'/components-demolition-zh-Hans.bmp')
gdi.DeleteObject(dib)
gdi.DeleteDC(S.dc)
print('PASS: '..#health.pages..' Health entities; Alpha Commander body/parts, shared fields, both editing directions, canonical persistence, uncatalogued entities, resets, search, nested demolition navigation and original enemy settings; no game writes')
]==]
assert(loadstring(start..checks,'@health-component-integration'))()
