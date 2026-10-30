-- Reuse the actual current-game bootstrap; neither live files nor the real profile are written.
local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
start=start:gsub('MOD=MOD,','MOD=MOD,keyboard=keyboard,',1)
local checks=[==[
local J=require('json_data');local F=require('preset_files');local R=E.MOD.record_names
local function open(tab)
 local parent,sub=assert(E.MOD.nav.locate(tab));state.nav_open(parent.id,sub);E.click('cat:'..tab)
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
assert(#H.diff()==0,'naming, searches and jumps must not modify game bytes')
gdi.DeleteDC(S.dc)
print('PASS: current-game hash/decimal active typing, filter-independent hash jump, strict TypeID search/jump scope, nine per-type JSONs, identical native controls and correct folder buttons; no game writes')
]==]
assert(loadstring(start..checks,'@naming-browser-integration'))()
