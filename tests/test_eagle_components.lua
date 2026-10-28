-- Verify EagleComponentData, EagleSpawnerComponentData, and Orbital & Eagle -> Eagle editing replacement.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,T_STRATAGEM=T_STRATAGEM,TYPES=TYPES,ui=ui,settings=settings,weapons_in=weapons_in,select_weapon=select_weapon,change=change,row_value=row_value,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs({'generated_projectile_settings.dl_bin','generated_stratagem_settings.dl_bin',
 'generated_damage_settings.dl_bin','generated_explosion_settings.dl_bin','generated_status_effect_settings.dl_bin',
 'generated_arc_settings.dl_bin','generated_beam_settings.dl_bin'})do
 local plain=read(TEST_FIXTURES..'/'..name)
 original[name]=G.seal(ffi.cast('const uint8_t *',plain),#plain)
end
assert(#H.load(TEST_GAME,original)==0)
]],1)

local checks=[==[
local V=require('component_view')
local eagle_spec=require('eagle_components')
local spawner_spec=require('eagle_spawner_components')

-- 1. Verify layouts against game type library
local ok1,why1=V.check_layout(eagle_spec,model.schemas,E.TYPES.eagle)
assert(ok1,tostring(why1))
local ok2,why2=V.check_layout(spawner_spec,model.schemas,E.TYPES.eagle_spawner)
assert(ok2,tostring(why2))

-- 2. Verify EagleComponentData & EagleSpawnerComponentData views
assert(E.MOD.eagle_components and #E.MOD.eagle_components.pages==11,'expected 11 EagleComponentData pages, got '..tostring(E.MOD.eagle_components and #E.MOD.eagle_components.pages))
for _,p in ipairs(E.MOD.eagle_components.pages)do
 assert(#p.rows==82,p.name..' expected 82 rows, got '..#p.rows)
 assert(p.name~=p.entity_hash,'expected human-readable name for '..p.entity_hash)
end

assert(E.MOD.eagle_spawner_components and #E.MOD.eagle_spawner_components.pages==3,'expected 3 EagleSpawnerComponentData pages, got '..tostring(E.MOD.eagle_spawner_components and #E.MOD.eagle_spawner_components.pages))
for _,p in ipairs(E.MOD.eagle_spawner_components.pages)do
 assert(#p.rows==6,p.name..' expected 6 rows, got '..#p.rows)
 assert(p.name~=p.entity_hash,'expected human-readable name for '..p.entity_hash)
 assert(p.by_id.eagle_type and p.by_id.eagle_type.row.reference_type=='stratagem_id')
end

-- 3. Verify Orbital & Eagle -> Eagle editing (轨道飞鹰 -> 飞鹰编辑)
local eagles=E.weapons_in('Eagle')
assert(#eagles>=10,'expected at least 10 Eagle stratagems, got '..#eagles)
local by_name={}
for _,w in ipairs(eagles)do
 by_name[w.name]=w
 local has_strat=false
 local has_eagle=false
 for _,r in ipairs(w.rows)do
  local allowed=(r.section=='StratagemType' or r.section=='StratagemType additional'
   or r.component=='EagleComponentData' or r.component=='EagleSpawnerComponentData')
  assert(allowed,w.name..' has disallowed row in Eagle editing: section='..tostring(r.section)..', component='..tostring(r.component)..', id='..tostring(r.id))
  if r.section=='StratagemType'then has_strat=true end
  if r.component=='EagleComponentData'then has_eagle=true end
 end
 assert(has_strat,w.name..' missing StratagemType rows')
 assert(has_eagle,w.name..' missing EagleComponentData rows')
end

-- Check specific Eagles
assert(by_name['Eagle 500kg Bomb'],'missing Eagle 500kg Bomb')
assert(by_name['Eagle Strafing Run'],'missing Eagle Strafing Run')
assert(by_name['Eagle Airstrike'],'missing Eagle Airstrike')
assert(by_name['Eagle Fly BY'],'missing Eagle Fly BY')

-- Check EagleSpawnerComponentData attached to matching Eagle stratagems
for _,name in ipairs({'Eagle Strafing Run','Eagle Gas Airstrike','Eagle Napalm Airstrike'})do
 local w=assert(by_name[name],name)
 local has_spawner=false
 for _,r in ipairs(w.rows)do
  if r.component=='EagleSpawnerComponentData'then has_spawner=true;break end
 end
 assert(has_spawner,name..' should include EagleSpawnerComponentData rows')
end

-- 4. Verify bidirectional sync between Eagle editing and Entity Components -> Eagle
local bomb500=by_name['Eagle 500kg Bomb']
E.select_weapon(bomb500)
local approach_part=assert(bomb500.by_id.eagle_approach,'missing eagle_approach')
local orig_val=E.row_value(approach_part.row)
E.change(approach_part.row,1,false,orig_val+50)
assert(math.abs(E.row_value(approach_part.row)-(orig_val+50))<1e-3,'after change: got '..tostring(E.row_value(approach_part.row))..' expected '..tostring(orig_val+50)..' msg='..tostring(E.ui.message and E.ui.message.text))
local comp_page=assert(E.MOD.eagle_components.by_entity['E44B691DC039A505'],'missing comp_page')
assert(math.abs(E.row_value(comp_page.by_id.eagle_approach.row)-(orig_val+50))<1e-3,'comp_page sync failed')
E.select_weapon(comp_page)
E.change(comp_page.by_id.eagle_approach.row,-1,false,orig_val)
assert(math.abs(E.row_value(approach_part.row)-orig_val)<1e-3,'restore failed')

-- 5. Render GDI screenshots of 轨道飞鹰 -> 飞鹰编辑 and 实体组件 -> 飞鹰
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end

state.nav_open('orbitals',2)
E.select_weapon(bomb500)
E.ui.row=40;E.ui.scroll=38
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/eagle_editing_500kg.bmp')

E.select_weapon(by_name['Eagle Strafing Run'])
E.ui.row=#by_name['Eagle Strafing Run'].rows;E.ui.scroll=#by_name['Eagle Strafing Run'].rows-23
E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/eagle_editing_strafing_spawner.bmp')

state.nav_open('components',14)
E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/eagle_components_page.bmp')
gdi.DeleteDC(S.dc)

print('PASS: EagleComponentData (82 fields, 11 entities), EagleSpawnerComponentData (6 fields, 3 entities), and Eagle editing replacement verified')
]==]

assert(loadstring(start..checks))()
