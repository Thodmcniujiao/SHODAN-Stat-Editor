-- Real DLs through the editor: empty/nonempty effect lists, exact IDs, presets, serialization and sealing.
-- No installation or network/game process access. Run with test_editor_demolition_sync's fixtures.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close();local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge',[[
SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model
SHODAN_PRELOAD_MODEL=require('preload_store').new({path=I.home..'/preload_config.json',load=function()error('No package load expected')end,
 changed=function()if state and state.preload_touch then state.preload_touch()end end})
]],1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs(I.list_files(TEST_GAME,'generated_*.dl_bin'))do if not original[name]then original[name]=read(TEST_GAME..'/'..name)end end
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local A=require('modifier_assignments');local store=SHODAN_PRELOAD_MODEL
local function open(tab)
 local nav,k=assert(E.MOD.nav.locate(tab));assert(nav.id=='planets')
 state.nav_open(nav.id,k);E.click('cat:'..tab);assert(E.ui.tab==tab)
end
local function row(p,id)for i,r in ipairs(p.rows)do if r.id==id then return r,i end end;error('row absent '..id)end
local function edit(p,id,value)
 local r,i=row(p,id);E.ui.weapon=p;E.click('value:'..i)
 assert(E.ui.value,'text input not opened');E.ui.value.text=value;assert(state.commit_value())
end
open('PlanetModifierLists')
local planets=E.weapons_in('PlanetModifierLists');assert(#planets==438,#planets)
local empty,nonempty
for _,p in ipairs(planets)do if #p.modifier_arrays[1].values==0 then empty=empty or p else nonempty=nonempty or p end end
assert(empty and nonempty);E.select_weapon(empty)
local key=empty.modifier_arrays[1].key
assert(A.check_array(empty.modifier_arrays[1].spec,model.schemas))
edit(empty,'append_1','火龙卷');assert(store:array_values(key)[1]=='7BAFBDB8D21D7D2A')
edit(empty,'append_1','0xBE5C2702BD514A76');assert(#store:array_values(key)==2)
assert(E.modified(empty))
edit(empty,'effect_1_1','0x9080B0090BC6F3AB');assert(store:array_values(key)[1]=='9080B0090BC6F3AB')
local reset_item=row(empty,'effect_1_2');E.reset_row(empty,reset_item);assert(#store:array_values(key)==1,'R did not remove an added item')
edit(empty,'append_1','0xBE5C2702BD514A76')
edit(empty,'effect_1_2','-');assert(#store:array_values(key)==1)
TEST_PRESETS_HELPER.save(E,empty,1);E.reset_weapon(empty);assert(#store:array_values(key)==0)
TEST_PRESETS_HELPER.load(E,empty,1);assert(#store:array_values(key)==1)
local ok=pcall(function()store:set_array(key,{'FFFFFFFFFFFFFFFF'})end);assert(not ok,'unknown entity accepted')
E.select_weapon(nonempty);local nk=nonempty.modifier_arrays[1].key;local original_count=#store:array_values(nk)
edit(nonempty,'effect_1_1','-');assert(#store:array_values(nk)==original_count-1)
open('GalacticModifierLists');local events=E.weapons_in('GalacticModifierLists');assert(#events==137,#events)
local storm
for _,p in ipairs(events)do if p.attachment_identity=='illuminate_ritual_storm_lvl3'then storm=p end end
assert(storm);E.select_weapon(storm)
local ak,bk=storm.modifier_arrays[1].key,storm.modifier_arrays[2].key
assert(#store:array_values(ak)==7 and #store:array_values(bk)==2)
edit(storm,'effect_2_1','0x826643D4EAF3B508')
assert(store:array_values(bk)[1]=='826643D4EAF3B508'and #store:array_values(ak)==7,'event arrays conflated')
local persisted=require('preload_store').new({path=I.home..'/preload_config.json'})
assert(persisted.cfg.arrays[key].values[1]=='9080B0090BC6F3AB')
-- Serialize three edited records in two files; after hash correction reopen and verify typed array contents.
local changes={};store:apply_arrays(changes,H,model.schemas);assert(#changes==2)
local verified=0
for _,ch in ipairs(changes)do
 local sealed,why=H.build(ch);assert(sealed,why)
 local back,n=G.open_sealed(sealed);assert(back and G.murmur64(back,n)==H.files[ch.name].hash)
 local hs=G.headers(back,n);local counts={}
 for _,h in ipairs(hs)do
  counts[h.type]=(counts[h.type]or 0)+1
  for _,a in ipairs({empty.modifier_arrays[1],nonempty.modifier_arrays[1],storm.modifier_arrays[2]})do local s=a.spec
   if ch.name==s.file and h.type==s.root and counts[h.type]==s.ordinal then
    local blob=ffi.string(back+h.at+24,h.size);local actual=A.values(blob,s.offset)
    assert(table.concat(actual,',')==table.concat(store:array_values(a.key),','));verified=verified+1
   end
  end
 end
 G.free(back)
end
assert(verified==3,verified)
-- A saved configuration cannot redirect an attachment into an unrelated array/type/domain.
local saved=store.cfg.arrays[key].spec.offset;store.cfg.arrays[key].spec.offset=56
assert(not pcall(function()store:apply_arrays({},H,model.schemas)end),'redirected descriptor accepted')
store.cfg.arrays[key].spec.offset=saved
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 for _,tab in ipairs({'PlanetModifierLists','GalacticModifierLists'})do
  open(tab);E.select_weapon(tab=='PlanetModifierLists'and nonempty or storm)
  E.tick();S.sleep(1300);E.tick();assert(state.ui_errors==0,state.ui_errors)
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..tab..'-'..lang..'.bmp')
 end
end
E.reset_all();assert(not next(store.cfg.arrays));assert(#H.diff()==0)
gdi.DeleteDC(S.dc)
print('PASS: 438 planet + 137 event attachment pages, exact named IDs, append/replace/delete, empty lists, persistence/presets/reset, two-file serializer + seal roundtrip, domain/offset guards, bilingual native render; no game writes')
]==]
assert(loadstring(start..checks,'@modifier-attachments-integration'))()
