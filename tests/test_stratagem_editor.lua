-- Current game tables are read only; profile, snapshots and rendered output are isolated.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local bootstrap=f:read('*a'):gsub('\r\n','\n');f:close()
local start=assert(bootstrap:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs({'generated_projectile_settings.dl_bin','generated_stratagem_settings.dl_bin',
 'generated_damage_settings.dl_bin','generated_explosion_settings.dl_bin','generated_status_effect_settings.dl_bin',
 'generated_arc_settings.dl_bin','generated_beam_settings.dl_bin'})do original[name]=read(TEST_GAME..'/'..name)end
local problems=H.load(TEST_GAME,original);assert(#problems==0,table.concat(problems,'; '))
]],1)
local checks=[==[
local armory,sub=E.MOD.nav.locate('Stratagems');assert(armory.id=='armory'and armory.subs[sub].name[2]=='战备编辑')
assert(armory.subs[sub-1].tabs[1]=='Attachments','stratagem editing must sit immediately after weapon attachments')
assert(E.MOD.nav.locate('Mechas')==armory)
local game,k=E.MOD.nav.locate('RecStratagem');assert(game.id=='gamedata'and #game.subs[k].tabs==1)
local new_model=assert(E.MOD.stratagem_entity_model)
assert(#new_model.roots>200)
local vehicle,sentry,backpack,mounted
for _,page in ipairs(E.weapons_in('Mechas'))do
 assert(page.stratagem_entity_groups and page.component_groups)
 if page.stratagem and page.stratagem.vehicle then vehicle=vehicle or page end
 if page.mounted then mounted=mounted or page end
end
for _,page in ipairs(E.weapons_in('Stratagems'))do
 assert(page.stratagem_entity_groups and page.component_groups)
 if page.sentry_defs and #page.sentry_defs>0 then sentry=sentry or page end
 if page.stratagem and page.stratagem.drone then backpack=backpack or page end
end
assert(vehicle and sentry and backpack and mounted,'expected real vehicle, sentry, guard dog and mounted gun')
local function find(page,typ)
 for _,g in ipairs(page.component_groups)do if g.type==typ or g.type:sub(1,#typ+1)==typ..':'then return g end end
end
local vg=assert(find(vehicle,'VehicleComponentData'))
assert(find(vehicle,'HealthComponentData')and find(vehicle,'MountComponentData'))
assert(not find(backpack,'DepositComponentData')and not find(backpack,'HellpodRackComponentData'),'a stratagem definition must not own payload components')
local deposit,rack,child_vehicle
for _,key in ipairs(backpack.related_entities)do
 local page=new_model.entity_pages.Stratagems[key]
 deposit=deposit or(page and find(page,'DepositComponentData'))
 rack=rack or(page and find(page,'HellpodRackComponentData'))
end
assert(deposit and rack,'payload/backpack components must remain available on their real entity pages')
for _,key in ipairs(vehicle.related_entities)do
 local page=new_model.entity_pages.Mechas[key]
 if key~=vehicle.stratagem_entity_key and page and find(page,'VehicleComponentData')then child_vehicle=page;break end
end
assert(child_vehicle,'expected separate related vehicle variant')
assert(find(child_vehicle,'VehicleComponentData').entity~=vg.entity)
for _,page in ipairs(new_model.pages)do
 local unnamed=false
 for _,g in ipairs(page.component_groups)do
  if g.field_kind then
   assert(g.entity==page.entity_hash,'a component from another entity leaked into this page')
   assert(g.field_offset==E.tables[g.field_kind].index[page.stratagem_entity_key])
  end
  if g.sub=='unknown'then unnamed=true;assert(g.type:match('^Component_0x'))
  else assert(not unnamed,'named components or relationship rows appeared below the unnamed group')end
 end
end
assert(find(mounted,'WeaponDataComponentData'))
for _,page in ipairs({vehicle,sentry,backpack,mounted})do
 assert(#page.rows==#page.component_groups,'components must start collapsed')
 for _,row in ipairs(page.rows)do assert(row.collapsed_component)end
end
E.select_weapon(vehicle);E.ui.tab='Mechas';E.MOD.nav.sync()
local legacy
for _,part in pairs(vehicle.by_id)do if part.field.kind==vg.field_kind and part.row and part.row.storage=='f32'then legacy=part;break end end
if legacy then
 local value=E.row_value(legacy.row)
 E.change(legacy.row,0,false,value==0 and 1 or value*.9)
 assert(vg.header.component_modified(),'legacy edits must mark an unopened full component')
 assert(not vg.loaded,'checking a collapsed star must not force full component row generation')
 E.reset_row(vehicle,legacy.row)
end
E.ui.expanded_components[vehicle.hash..':'..vg.type]=true;vehicle.sync_rows(vg.type)
assert(vg.loaded and #vg.rows>100,'vehicle record must expose its full inline component fields')
local editable
for _,row in ipairs(vg.rows)do if row.storage=='f32'and row.parts[1]and E.row_value(row)~=nil then editable=row;break end end
assert(editable)
local original_value=E.row_value(editable);local target=original_value==0 and 1 or original_value*.9
E.change(editable,0,false,target);assert(math.abs(E.row_value(editable)-target)<.001)
assert(vg.header.component_modified(),'collapsed component must retain the changed star')
local preset=TEST_PRESETS_HELPER.save(E,vehicle,'vehicle-full');assert(E.save_config())
write(TEST_WORK..'/saved_config.txt',read(I.home..'/config.txt'))
local owner=editable.parts[1].health_owner;assert(owner)
write(TEST_WORK..'/saved_probe.json',require('json_data').encode({hash=owner.weapon.hash,id=owner.part.id,value=target}))
E.reset_row(vehicle,editable);assert(E.row_value(editable)==original_value)
TEST_PRESETS_HELPER.load(E,vehicle,'vehicle-full');assert(math.abs(E.row_value(editable)-target)<.001)
E.reset_row(vehicle,editable);assert(E.row_value(editable)==original_value)
-- Exact shared fields: the mounted gun's magazine uses the component page's field object.
local magazine=find(mounted,'WeaponMagazineComponentData');assert(magazine)
magazine.load();assert(#magazine.rows>8)
-- Changing a child must not mark/reset the parent as if it owned the child's fields.
local child
for _,key in ipairs(vehicle.related_entities)do
 local page=new_model.entity_pages.Mechas[key]
 if page and page~=vehicle and find(page,'WeaponMagazineComponentData')then child=page;break end
end
assert(child)
local child_group=find(child,'WeaponMagazineComponentData');child_group.load()
local child_row
for _,row in ipairs(child_group.rows)do if #row.parts==1 and row.storage=='u32'and row.max>0 then child_row=row;break end end
assert(child_row)
local child_before=E.row_value(child_row);local child_target=child_before==0 and 1 or child_before-1
E.change(child_row,0,false,child_target)
assert(E.MOD.page_changed(child),'the owning entity must show the changed star')
assert(not E.MOD.page_changed(vehicle),'a child change must not mark an unrelated parent component')
E.reset_weapon(vehicle)
assert(E.row_value(child_row)==child_target,'resetting the parent must not reset the child')
for _,group in ipairs(vehicle.component_groups)do if group.field_kind and group.loaded then
 local size;for _,root in ipairs(new_model.roots)do if root[1]==group.field_kind then size=root[2];break end end
 for _,row in ipairs(group.rows)do for _,part in ipairs(row.parts)do
  local field=part.field
  assert(field.kind==group.field_kind and field.offset>=group.field_offset and field.offset<group.field_offset+size,'a loaded component row includes another entity record')
 end end
end end
E.reset_row(child,child_row)
local relations=assert(find(vehicle,'EntityReferences'));relations.load()
local link=assert(relations.rows[1]);assert(link.entity_target and link.custom_action())
assert(E.ui.weapon==link.entity_target,'entity-reference navigation did not open the target entity')
local generic
for _,g in ipairs(vehicle.component_groups)do if g.type:match('^Component_0x')then generic=g;break end end
if generic then generic.load();assert(#generic.rows>0,'unknown named components still need typed fields')end
local function render(page,lang,suffix)
 E.settings.lang=lang;S.lang=function()return lang end;E.ui.tab=E.MOD.nav.tab_of(page);E.select_weapon(page);E.MOD.nav.sync()
 if suffix=='vehicle-expanded-zh'then
  for i,row in ipairs(page.rows)do if row.component==vg.type then E.ui.scroll=i;E.ui.row=i;break end end
 end
 S.w,S.h=1460,1080;S.version=S.version+1;E.ui.version=E.ui.version+1
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
 local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
 local prior=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0,'stratagem component render failed')
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..suffix..'.bmp')
 gdi.SelectObject(S.dc,prior);gdi.DeleteObject(dib)
end
render(vehicle,'zh-Hans','vehicle-expanded-zh')
E.ui.expanded_components[vehicle.hash..':'..vg.type]=nil;vehicle.sync_rows()
render(vehicle,'zh-Hans','vehicle-collapsed-zh')
render(backpack,'en','guard-dog-en');render(child_vehicle,'zh-Hans','related-vehicle-zh');render(sentry,'zh-Hans','sentry-zh');render(mounted,'zh-Hans','mounted-zh')
assert(#H.diff()==0,'navigation/components/presets must not mutate shared game tables')
gdi.DeleteDC(S.dc)
print('PASS: Armory stratagem navigation, all keyed ECS membership, vehicle/sentry/backpack/mounted components, lazy folds/stars, shared fields, editing/reset/config/preset roundtrip, bilingual native renders; no game writes')
]==]
assert(loadstring(start..checks,'@stratagem-editor-integration'))()
