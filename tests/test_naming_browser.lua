-- Reuse the actual current-game bootstrap; neither live files nor the real profile are written.
local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
start=start:gsub('MOD=MOD,','MOD=MOD,keyboard=keyboard,',1)
local checks=[==[
local J=require('json_data');local F=require('preset_files');local R=E.MOD.record_names
local function open(tab)
 local parent,sub=assert(E.MOD.nav.locate(tab));state.nav_open(parent.id,sub);E.click('cat:'..tab)
 if E.ui.tab~=tab then E.ui.tab=tab end
 assert(E.ui.tab==tab);E.ui.search={text='',active=false}
end
local function type_id(text)
 E.ui.record_id={text='',active=true}
 for c in text:gmatch('.')do S.push_typed(c:byte());E.keyboard(1)end
 assert(E.ui.record_id.text==text and E.ui.record_id.active,'typing must retain focus and buffer after jumping')
end
local catalog=state.component_catalog();assert(not catalog.config_error,tostring(catalog.config_error))
local alpha=catalog.by_entity.health.EF79CD8BB654397DF
open('HealthComponents');state.component_filter('other',false)
type_id('17842374123104475103')
assert(E.ui.weapon==alpha and E.ui.tab=='HealthComponents','decimal input must jump without Enter')
type_id('0xf79cd8bb654397df');assert(E.ui.weapon==alpha)
type_id('F79CD8BB654397DF');assert(E.ui.weapon==alpha)
E.ui.record_id.active=false
-- A hash target that the component filter hides must still be reachable.
local missing;for _,p in ipairs(catalog.views.health)do if not p.has_component then missing=p;break end end
assert(missing);E.ui.record_id.text=missing.entity_hash;assert(R.jump_active())
assert(E.ui.weapon==missing and E.settings.component_show_missing)
-- Same integer in multiple TypeIDs must never mix the two search namespaces.
local shot,blast
for _,p in ipairs(E.weapons_in('RecProjectile'))do
 for _,q in ipairs(E.weapons_in('RecExplosion'))do if p.id==q.id then shot,blast=p,q;break end end
 if shot then break end
end
assert(shot and blast)
local function custom(t,id,name)
 local path=R.folder..'/'..t..'.json';local data=J.decode(assert(F.read(path)))
 data.names[tostring(id)]=name;assert(F.write(path,J.encode(data)))
end
custom('projectile',shot.id,'OnlyProjectileName');custom('explosion',blast.id,'OnlyExplosionName')
local _,errors=R.reload();assert(#errors==0,errors[1])
open('RecProjectile');E.ui.search.text='OnlyExplosionName';assert(#E.weapons_in('?search')==0)
E.ui.search.text='OnlyProjectileName';assert(#E.weapons_in('?search')==1)
type_id(tostring(shot.id));assert(E.ui.weapon==shot and E.ui.tab=='RecProjectile')
open('RecExplosion');type_id('0x'..string.format('%X',blast.id));assert(E.ui.weapon==blast)
-- Backing entity hashes and foreign TypeID indices cannot be used as local component indices.
open('Eagle');local eagles=E.weapons_in('Eagle');assert(eagles[1].component_index==0)
type_id('0');assert(E.ui.weapon==eagles[1])
for _,p in ipairs(eagles)do for _,key in ipairs(p.component_keys)do
 assert(not R.jump('Eagle','0x'..D.hex(key)),'index jump accepted an EntityHash')
end end
open('OrbitalBeam');local beam=assert(E.weapons_in('OrbitalBeam')[1])
local decimal=E.MOD.orbital.decimal(beam.key)
type_id(decimal);assert(E.ui.weapon==beam)
E.ui.search.text=decimal;local found=false
for _,page in ipairs(E.weapons_in('?search'))do if page==beam then found=true end end
assert(found,'hash list decimal search missing')
for _,tab in ipairs({'damage','projectile','explosion','arc','beam','status','stratagem','bombardment','eagle'})do
 local data=J.decode(assert(F.read(R.folder..'/'..tab..'.json')));assert(data.type==tab)
end
-- The two kinds of list have identical input/button/search geometry in the native renderer.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
E.tick();S.sleep(1700);E.tick()
local layouts={}
for _,tab in ipairs({'HealthComponents','RecProjectile','Eagle'})do
 open(tab);E.tick();assert(state.ui_errors==0)
 local positions={}
 for _,r in ipairs(E.ui.regions)do
  if r.key=='record_id'or r.key=='search'or r.key=='component_reload'or r.key=='record_names_reload'
     or r.key=='component_config'or r.key=='record_names_folder'then
   local key=r.key:find('reload')and'reload'or(r.key=='component_config'or r.key=='record_names_folder')and'folder'or r.key
   positions[key]={r.x,r.y,r.w,r.h}
  end
 end
 for _,key in ipairs({'record_id','search','reload','folder'})do assert(positions[key],tab..': missing '..key)end
 layouts[#layouts+1]=positions
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/naming-'..tab..'.bmp')
end
for n=2,#layouts do for key,pos in pairs(layouts[1])do for i=1,4 do assert(layouts[n][key][i]==pos[i],key..' layout mismatch')end end end
local opened;E.settings.open=function(path)opened=path;return true end
open('HealthComponents');E.click('component_config');assert(opened==catalog.folder:gsub('/','\\'))
open('Eagle');E.click('record_names_folder');assert(opened==R.folder:gsub('/','\\'))

-- Right-click context menu: 设置分组 and 更改策划名 on all entity name and typeidindex list items
local function find_menu_item(label)
 for i,item in ipairs(assert(E.ui.context_menu,'missing context menu').items)do
  if item.label==label then return i,item end
 end
end
for _,tab in ipairs({'Primary','Secondary','Support','Throwables','Terminids','Automatons','Illuminate','SEAF',
 'HealthComponents','OrbitalBeam','RecDamage','RecProjectile','RecExplosion','RecArc','RecBeam','RecStatus','RecStratagem','Orbital','Eagle','Stratagems','Mechas'})do
 open(tab);local first=assert(E.weapons_in(tab)[1],tab..' empty')
 E.MOD.clipboard.right_click('weapon:'..first.hash,120,260)
 local n_items=#E.ui.context_menu.items
 assert(n_items==4 or n_items==5,tab..': expected 4 or 5 right-click menu items, got '..n_items)
 assert(find_menu_item('设置分组'),tab..': missing 设置分组 in right-click menu')
 assert(find_menu_item('更改策划名'),tab..': missing 更改策划名 in right-click menu')
 E.ui.context_menu=nil
end
-- Test 更改策划名 and 设置分组 on Armory -> Weapon editing (Primary)
open('Primary')
local primary_w=assert(E.weapons_in('Primary')[1])
local orig_primary_name=primary_w.name
E.MOD.clipboard.right_click('weapon:'..primary_w.hash,120,260)
assert(#E.ui.context_menu.items==5,'Primary weapon must have 5 right-click menu items')
E.click('context_item:'..assert(find_menu_item('更改策划名')))
assert(E.ui.design_name and E.ui.design_name.page==primary_w)
E.ui.design_name.text='主武器策划名测试';E.click('design_name:save')
assert(E.MOD.item_naming.custom_name_of(primary_w)=='主武器策划名测试')
E.MOD.clipboard.right_click('weapon:'..primary_w.hash,120,260)
E.click('context_item:'..assert(find_menu_item('设置分组')))
E.ui.item_group.text='主力步枪组';E.click('item_group:save')
assert(E.MOD.item_naming.custom_group_of(primary_w)=='主力步枪组')
-- Restore Primary weapon default name and group
E.MOD.clipboard.right_click('weapon:'..primary_w.hash,120,260)
E.click('context_item:'..assert(find_menu_item('更改策划名')));E.click('design_name:reset')
assert(primary_w.name==orig_primary_name)
E.MOD.clipboard.right_click('weapon:'..primary_w.hash,120,260)
E.click('context_item:'..assert(find_menu_item('设置分组')));E.click('item_group:reset')
-- Test 更改策划名 and 设置分组 on entity name list item (HealthComponents)
open('HealthComponents');state.component_filter('all',true)
E.MOD.clipboard.right_click('weapon:'..alpha.hash,120,260)
local idx_name=assert(find_menu_item('更改策划名'))
E.click('context_item:'..idx_name);assert(E.ui.design_name and E.ui.design_name.page==alpha)
E.ui.design_name.text='右键测试实体名';E.click('design_name:save');assert(not E.ui.design_name)
assert(alpha.name=='右键测试实体名','entity design name not updated')
E.MOD.clipboard.right_click('weapon:'..alpha.hash,120,260)
local idx_grp=assert(find_menu_item('设置分组'))
E.click('context_item:'..idx_grp);assert(E.ui.item_group and E.ui.item_group.page==alpha)
E.ui.item_group.text='右键新建实体分组';E.click('item_group:save');assert(not E.ui.item_group)
assert(alpha.catalog_record.category_name=='右键新建实体分组','entity group not updated')
-- Restore entity default name and group
E.MOD.clipboard.right_click('weapon:'..alpha.hash,120,260)
E.click('context_item:'..assert(find_menu_item('更改策划名')));E.click('design_name:reset')
E.MOD.clipboard.right_click('weapon:'..alpha.hash,120,260)
E.click('context_item:'..assert(find_menu_item('设置分组')));E.click('item_group:pick:bugs')
assert(alpha.catalog_record.category=='bugs')

-- Test 更改策划名 and 设置分组 on typeidindex list item (RecProjectile)
open('RecProjectile')
E.MOD.clipboard.right_click('weapon:'..shot.hash,120,260)
E.click('context_item:'..assert(find_menu_item('更改策划名')))
assert(E.ui.design_name and E.ui.design_name.page==shot)
E.ui.design_name.text='右键射弹策划名';E.click('design_name:save')
assert(R.name('projectile',shot.id)=='右键射弹策划名')
E.MOD.clipboard.right_click('weapon:'..shot.hash,120,260)
E.click('context_item:'..assert(find_menu_item('设置分组')))
assert(E.ui.item_group and E.ui.item_group.page==shot)
E.ui.item_group.text='右键射弹分组';E.click('item_group:save')
assert(R.group('projectile',shot.id)=='右键射弹分组')
E.click('record_cat:右键射弹分组')
local filtered_proj=E.weapons_in('RecProjectile')
assert(#filtered_proj==1 and filtered_proj[1]==shot,'TypeID group filter failed')
E.click('record_cat:all')

-- Test parameter input box: vertical caret line, periodic blinking, and selection highlight/text color change
E.select_weapon(shot)
local edit_row_idx
for n,r in ipairs(shot.rows)do
 if not r.collapsed_component and not r.readonly_text and not r.link_only and not r.empty and E.row_value(r)~=nil then
  edit_row_idx=n;break
 end
end
assert(edit_row_idx,'no editable parameter row on projectile page')
E.ui.scroll=math.max(1,edit_row_idx-2)
E.click('value:'..edit_row_idx)
assert(E.ui.value and E.ui.value.n==edit_row_idx and E.ui.value.fresh)
local t0=assert(E.ui.value.touched)
E.ui.value.text='12345';E.MOD.text.all(E.ui.value,t0)
E.ui.version=E.ui.version+1;E.tick()
local function inspect_gui_input()
 local has_caret,has_sel_bg,has_sel_fg,has_white_text,has_underscore=false,false,false,false,false
 for _,item in ipairs(E.ui.gui.items)do
  if item.kind=='rect'and item.c then
   if item.c[2]==255 and item.c[3]==245 and item.c[4]==120 then has_caret=true end
   if item.c[2]==38 and item.c[3]==112 and item.c[4]==210 then has_sel_bg=true end
  elseif item.kind=='text'then
   if item.text=='12345'or item.text=='123'or item.text=='45'then
    if item.c[2]==255 and item.c[3]==232 and item.c[4]==88 then has_sel_fg=true end
    if item.c[2]==238 and item.c[3]==242 and item.c[4]==246 then has_white_text=true end
   end
   if item.text:find('12345_',1,true)then has_underscore=true end
  end
 end
 return has_caret,has_sel_bg,has_sel_fg,has_white_text,has_underscore
end
local caret1,sel_bg1,sel_fg1,_,under1=inspect_gui_input()
assert(caret1,'vertical caret line must be drawn in visible blink phase')
assert(sel_bg1 and sel_fg1,'full selection must draw selection background and highlight text color')
assert(not under1,'parameter input must not append underscore as caret')
-- Partial selection: '123' unselected (WHITE), '45' selected (SEL_FG on SEL_BG)
E.ui.value.fresh=false;E.ui.value.anchor=5;E.ui.value.at=3
E.MOD.text.touch(E.ui.value,E.ui.value.touched)
E.ui.version=E.ui.version+1;E.tick()
local caret2,sel_bg2,sel_fg2,white2=inspect_gui_input()
assert(caret2 and sel_bg2 and sel_fg2 and white2,'partial selection must draw both unselected WHITE text and selected SEL_FG text')
-- Simulate blink off half-period
E.ui.value.touched=E.ui.value.touched-0.6
E.tick()
local caret_off=inspect_gui_input()
assert(not caret_off,'vertical caret line must blink off in the second half-period')
-- Simulate blink back on in next period
E.ui.value.touched=E.ui.value.touched-0.55
E.tick()
local caret_on_again=inspect_gui_input()
assert(caret_on_again,'vertical caret line must blink back on in the next period')
E.ui.value=nil

assert(#H.diff()==0,'naming, searches and jumps must not modify game bytes')
gdi.DeleteDC(S.dc)
print('PASS: current-game hash/decimal active typing, filter-independent hash jump, strict TypeID search/jump scope, right-click 设置分组/更改策划名 on entity & TypeID lists, and blinking vertical caret + selection highlight; no game writes')
]==]
assert(loadstring(start..checks,'@naming-browser-integration'))()
