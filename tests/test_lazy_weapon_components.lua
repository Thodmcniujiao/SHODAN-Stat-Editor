local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
start=start:gsub('MOD=MOD,',[[MOD=MOD,field_at=field_at,default_of=default_of,restore_values=function(values)
 for _,o in ipairs(values)do overrides[#overrides+1]={hash=o.hash,id=o.id,value=o.value}end
 pending=values;apply_at=1;return apply_config(nil)
end,]],1)
local checks=[==[
local weapon,group
for _,w in ipairs(E.weapons)do for _,g in ipairs(w.component_groups or{})do
 if g.spec and g.spec.KEY=='weapon_customization'and not g.loaded and not g.page.rows_built then weapon,group=w,g;break end
end;if weapon then break end end
assert(weapon and group,'full weapon customization was eagerly built')
assert(#weapon.all_component_rows==0)
local preview_field
for _,f in ipairs(group.spec.FIELDS)do if f[3]=='f32'and f[9]and f[9].id then preview_field=f;break end end
assert(preview_field)
local preview_id=preview_field[9].id
local tree=require('preset_details').build({values={{hash=group.page.hash,id=preview_id,value=.5}},data={}},{
 by_hash=E.by_hash,lang=function()return'en'end,tr=function(s)return s end,navigation=E.MOD.nav.PAGES,
 tab_of=E.MOD.nav.tab_of,default_value=state.vanilla})
local preview
for _,p in ipairs(tree)do for _,section in ipairs(p.sections)do for _,r in ipairs(section.rows)do if r.id==preview_id then preview=r end end end end
assert(preview and preview.baseline~=nil and preview.label~=preview_id,'unopened component preset lost its label/default')
assert(group.page.rows_built and not group.loaded,'preset preview built the weapon groups')
group.page.ensure_rows();assert(not group.loaded,'opening the component view opened its weapon group')
local bit_page,bit_row
for _,g in ipairs(weapon.component_groups)do
 local bits=false;for _,f in ipairs(g.spec.FIELDS)do if f[3]:match('^bit%d')then bits=true;break end end
 if bits then
  g.page.ensure_rows()
  for _,r in ipairs(g.page.rows)do if #r.parts==1 and r.parts[1].field.mask then bit_page,bit_row=g.page,r;break end end
 end
 if bit_row then break end
end
assert(bit_row,'no real packed field available for lazy-baseline regression')
local bit_before=E.row_value(bit_row);local bit=bit_row.parts[1].field
E.select_weapon(bit_page);E.change(bit_row,0,false,1-bit_before)
local shift=math.floor(math.log(bit.mask)/math.log(2)+.5)
local alias_bit=E.field_at(bit.kind,bit.offset,'bits1_'..shift..'_1',1)
assert(E.default_of(alias_bit)==bit_before,'late packed alias captured edited bytes as its original')
E.reset_row(bit_page,bit_row);assert(E.row_value(bit_row)==bit_before)
local row
for _,r in ipairs(group.page.rows)do local value=E.row_value(r)
 if #r.parts==1 and r.storage=='f32'and not r.choice and type(value)=='number'and math.abs(value)<10000 then row=r;break end
end
assert(row,'no editable customization scalar')
local before=E.row_value(row)
E.select_weapon(group.page);E.change(row,0,false,before+.25)
assert(group.modified()and E.MOD.page_changed(weapon),'shared edit not marked on the unopened weapon group')
assert(not group.loaded,'star checking eagerly built the group')
E.reset_row(group.page,row);assert(E.row_value(row)==before)
local alias=group.spec.KEY..'_'..row.parts[1].id
local refused=state.refused;assert(E.restore_values({{hash=weapon.hash,id=alias,value=before+.5}}))
assert(state.refused==refused and group.loaded,'old prefixed saved ID failed before first group expansion')
assert(weapon.by_id[alias].field==row.parts[1].field)
assert(math.abs(E.row_value(row)-(before+.5))<.0001)
assert(E.MOD.page_changed(weapon)and group.modified())
local preset=TEST_PRESETS_HELPER.save(E,weapon,'lazy')
E.reset_weapon(weapon);assert(E.row_value(row)==before)
TEST_PRESETS_HELPER.load(E,weapon,'lazy');assert(math.abs(E.row_value(row)-(before+.5))<.0001)
E.reset_weapon(weapon);assert(E.row_value(row)==before)
-- A stable export is not rebuilt or rewritten on subsequent starts/requests.
local catalog=E.MOD.component_catalog
assert(catalog:export_index()==false,'unchanged entity index was rewritten')
local record=catalog.records[1];local old_name=record.name;record.name=old_name..' cache-test'
assert(catalog:export_index()==true,'changed names did not invalidate the index')
record.name=old_name;assert(catalog:export_index()==true)
local built=0;for _,views in pairs(E.MOD.weapon_component_views)do for _,page in ipairs(views.pages)do if page.rows_built then built=built+1 end end end
assert(built<20,'unrelated component pages were forced during edits/reset/presets')
local hash=weapon.hash
E.after_pass(1,true)
repeat E.tick();assert(state.phase~='gave_up',state.status)until state.phase=='ready'
local fresh=assert(E.by_hash[hash]);local part=assert(E.MOD.parts_of(fresh,alias))[1]
assert(math.abs(E.row_value(part.row)-before)<.0001,'rescan reused stale lazy rows/owners')
E.select_weapon(fresh);E.change(part.row,0,false,before+.25);E.reset_weapon(fresh)
assert(math.abs(E.row_value(part.row)-before)<.0001)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
E.select_weapon(fresh);E.MOD.nav.sync()
for _,g in ipairs(fresh.component_groups)do E.ui.expanded_components[fresh.hash..':'..g.type]=nil end
fresh.sync_rows();E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/lazy-weapon-collapsed.bmp')
assert(E.ui.weapon==fresh)
E.click('comp_toggle:WeaponCustomizationComponentData');assert(#fresh.rows>100,'component header click did not expand')
E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/lazy-weapon-expanded.bmp')
assert(#H.diff()==0,'lazy component test left game memory changed')
print('PASS: unopened weapon groups stay lazy; shared stars, old saved aliases, reset and named-preset roundtrip work; index export invalidates only on data/name changes; no game writes')
]==]
assert(loadstring(start..checks,'@lazy-weapon-components'))()
