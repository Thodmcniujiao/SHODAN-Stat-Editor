local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close();local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge',[[
SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model
local PreloadIO=require('preload_io');local PreloadStore=require('preload_store')
local preload_reader=PreloadIO.new({raw=assert(os.getenv('SHODAN_PRELOAD_RAW')),game=TEST_GAME,owned=function()return{}end})
SHODAN_PRELOAD_MODEL=PreloadStore.new({path=I.home..'/preload_config.json',load=function(h)return preload_reader:load(h)end,
 changed=function()if state and state.preload_touch then state.preload_touch()end end})
]],1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs(I.list_files(TEST_GAME,'generated_*.dl_bin'))do if not original[name]then original[name]=read(TEST_GAME..'/'..name)end end
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local model=SHODAN_PRELOAD_MODEL
local function open(tab)
 local nav,k=E.MOD.nav.locate(tab);assert(nav.id=='misc'and nav.subs[k].tabs[1]=='PreloadExtra');state.nav_open(nav.id,k);E.click('cat:'..tab)
end
local function row(p,id)for i,r in ipairs(p.rows)do if r.id==id then return r,i end end;error('row absent '..id)end
local function edit(p,id,value)
 local r,i=row(p,id);E.ui.weapon=p;E.click('value:'..i)
 assert(E.ui.value,'text input not opened');E.ui.value.text=value;assert(state.commit_value())
 return r
end
open('PreloadGlobal')
local global
for _,p in ipairs(E.weapons_in('PreloadGlobal'))do if p.name=='packages/content/global_resources'then global=p end end
assert(global);E.select_weapon(global);local n=#model:entries('18235E0C9EC0E636')
edit(global,'add_resource','texture 0xFEDCBA9876543210');assert(#model:entries('18235E0C9EC0E636')==n+1)
assert(E.modified(global))
TEST_PRESETS_HELPER.save(E,global,1);E.reset_weapon(global);assert(#model:entries('18235E0C9EC0E636')==n)
TEST_PRESETS_HELPER.load(E,global,1);assert(#model:entries('18235E0C9EC0E636')==n+1)
E.reset_weapon(global)
open('PreloadExtra');local plan=E.weapons_in('PreloadExtra')[1];E.select_weapon(plan)
edit(plan,'add_donor','packages/content/env_desert_shared');assert(model.cfg.selected['324E128327AC29AB'])
edit(plan,'add_target','packages/content/env_arctic_shared');assert(model.cfg.targets['7371C64D957E5C74'])
local _,idx=row(plan,'preview');E.click('preload_action:'..idx);assert(model.report.resources>0)
E.ui.search.text='env_forest_shared';local _,filter_index=row(plan,'filter');E.click('preload_action:'..filter_index)
assert(model.cfg.selected['6CE0CE00D6FF8DAF']);E.ui.search.text=''
assert(model:toggle('selected','6CE0CE00D6FF8DAF',false))
open('PreloadWorld');local environment
for _,p in ipairs(E.weapons_in('PreloadWorld'))do if p.root_type==0x68E17506 and p.name:find('arctic',1,true)then environment=p;break end end
assert(environment);E.select_weapon(environment)
local _,index=row(environment,'append_selected_1');E.click('preload_action:'..index)
local arraykey;for k,a in pairs(model.arrays)do if a.spec.root==0x68E17506 and a.spec.ordinal==tonumber(environment.source_block)then arraykey=k end end
assert(arraykey and #model:array_values(arraykey)==1)
edit(environment,'append_one_1','packages/content/env_forest_shared');assert(#model:array_values(arraykey)==2)
edit(environment,'array_1_1','-');assert(#model:array_values(arraykey)==1)
TEST_PRESETS_HELPER.save(E,environment,2);E.reset_weapon(environment);assert(#model:array_values(arraykey)==0)
TEST_PRESETS_HELPER.load(E,environment,2);assert(#model:array_values(arraykey)==1)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 for _,tab in ipairs({'PreloadExtra','PreloadGlobal','PreloadWorld','PreloadCatalog'})do
  open(tab)
  if tab=='PreloadGlobal'then E.select_weapon(global)elseif tab=='PreloadWorld'then E.select_weapon(environment)end
  E.tick();S.sleep(1300);E.tick();assert(state.ui_errors==0,state.ui_errors)
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..tab..'-'..lang..'.bmp')
 end
end
E.reset_all();assert(not next(model.cfg.selected)and not next(model.cfg.edits)and not next(model.cfg.arrays))
assert(#H.diff()==0);gdi.DeleteDC(S.dc)
print('PASS: editable global/catalog manifests, add/delete, extra selection/targets/preview, empty environment array append/remove, original controls and presets/reset, bilingual native render; no game writes')
]==]
assert(loadstring(start..checks,'@preload-authoring-integration'))()
