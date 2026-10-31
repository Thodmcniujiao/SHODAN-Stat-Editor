-- Named character/font fields through the actual editor, isolated profile, authenticated build/readback.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
original['generated_font_settings.dl_bin']=read(TEST_GAME..'/generated_font_settings.dl_bin')
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local C=E.MOD.identity
assert(C.font_layout(model.schemas)and not C.font_layout({}))
local schema=model.schemas[C.FONT];local old=schema.size;schema.size=104
assert(not C.font_layout(model.schemas));schema.size=old
local chars=E.weapons_in('CharacterNameFields');local fonts=E.weapons_in('FontStyleFields')
assert(#chars==91,#chars);assert(#fonts==6,#fonts)
local misc=E.MOD.nav.page('misc');local _,parsed_sub=E.MOD.nav.locate('CharacterNameFields')
assert(misc.subs[parsed_sub].name[2]=='其他已解析字段')
assert(table.concat(misc.subs[parsed_sub].tabs,',')=='CharacterNameFields,FontStyleFields,IdentityRpcInfo')
local count=0
for _,p in ipairs(chars)do
 assert(#p.rows==4 and E.by_hash[p.hash]==p)
 E.ui.weapon=p
 for _,s in ipairs(C.CHAR_SPEC.FIELDS)do
  local r=assert(p.by_id[s[9].id]).row;local f=r.parts[1].field
  local t=E.tables[f.kind];local address=t.copies[1]+24+f.offset
  local size=s[3]=='flag'and 1 or 4
  local before=ffi.string(ffi.cast('const void *',address-4),size+8)
  local old=E.row_value(r);local value=s[3]=='flag'and 1-old or s[1]=='race'and 2 or 1069547521
  E.change(r,0,false,value);assert(E.row_value(r)==value,s[1])
  local now=ffi.string(ffi.cast('const void *',address-4),size+8)
  assert(now:sub(1,4)==before:sub(1,4)and now:sub(size+5)==before:sub(size+5),s[1]..' touched neighboring bytes')
  E.reset_row(p,r);assert(E.row_value(r)==old)
  count=count+1
 end
end
assert(count==364 and #H.diff()==0)
for _,p in ipairs(fonts)do
 assert(#p.rows==123,#p.rows)
 E.ui.weapon=p
 for _,r in ipairs(p.rows)do if not r.empty then
  assert(#r.parts==1)
  local f=r.parts[1].field;local t=E.tables[f.kind];local address=t.copies[1]+24+f.offset
  local before=ffi.string(ffi.cast('const void *',address-4),12)
  local old=E.row_value(r);local value=r.storage=='f32'and 1.25 or old==1 and 2 or 1
  E.change(r,0,false,value);assert(E.row_value(r)==value,r.id)
  local now=ffi.string(ffi.cast('const void *',address-4),12)
  assert(now:sub(1,4)==before:sub(1,4)and now:sub(9)==before:sub(9),r.id..' touched neighboring bytes')
  E.reset_row(p,r);assert(E.row_value(r)==old)
  count=count+1
 end end
end
assert(count==1084 and #H.diff()==0)
local main
for _,p in ipairs(chars)do if p.entity_hash=='4D1C334D294DFA97' then main=p end end
assert(main);E.ui.weapon=main
E.change(main.by_id.character_name.row,0,false,1069547521)
local diff=H.diff();assert(#diff==1 and #diff[1].floats==0,'integer name IDs used as float checksum salt')
diff[1].demolition_schemas=model.schemas
local cipher,why=H.build(diff[1]);assert(cipher,why)
local plain,n=G.open_sealed(cipher);assert(plain and G.murmur64(plain,n)==diff[1].hash)
local f=main.by_id.character_name.field;local file=H.files['generated_entities.dl_bin']
local off=E.tables[f.kind].copies[1]+24+f.offset-tonumber(ffi.cast('uintptr_t',file.p))
assert(tonumber(ffi.cast('uint32_t *',plain+off)[0])==1069547521);G.free(plain)
assert(E.save_config());TEST_PRESETS_HELPER.save(E,main,1)
E.reset_weapon(main);TEST_PRESETS_HELPER.load(E,main,1)
assert(E.row_value(main.by_id.character_name.row)==1069547521);E.reset_weapon(main)
local p=fonts[1];E.ui.weapon=p
local style=p.by_id.hud_0_style.row;local size=p.by_id.hud_0_font_size.row
E.change(style,0,false,1069547521)
diff=H.diff();assert(#diff==1 and #diff[1].floats==0,'font enum used as float checksum salt')
E.change(size,0,false,33.25)
diff=H.diff();assert(#diff==1 and #diff[1].floats==1)
local cipher,why=H.build(diff[1]);assert(cipher,why)
local plain,n=G.open_sealed(cipher);assert(plain and G.murmur64(plain,n)==diff[1].hash)
local file=H.files['generated_font_settings.dl_bin']
for _,r in ipairs({style,size})do
 local f=r.parts[1].field
 local off=E.tables[f.kind].copies[1]+24+f.offset-tonumber(ffi.cast('uintptr_t',file.p))
 local value=r.storage=='f32'and tonumber(ffi.cast('float *',plain+off)[0])or tonumber(ffi.cast('uint32_t *',plain+off)[0])
 assert(value==E.row_value(r),'built font value differs')
end
G.free(plain)
assert(E.save_config());TEST_PRESETS_HELPER.save(E,p,1)
E.reset_weapon(p);TEST_PRESETS_HELPER.load(E,p,1)
assert(E.row_value(style)==1069547521 and E.row_value(size)==33.25);E.reset_weapon(p)
assert(#H.diff()==0)
local function open(tab)
 local page,k=E.MOD.nav.locate(tab);assert(page.id=='misc'and k==parsed_sub)
 state.nav_open(page.id,k);E.click('cat:'..tab)
end
open('CharacterNameFields');E.select_weapon(main);E.ui.search.text='4D1C334D294DFA97'
assert(#E.weapons_in('?search')==1)
E.ui.search.text=''
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 for _,tab in ipairs({'CharacterNameFields','FontStyleFields','IdentityRpcInfo'})do
  open(tab);if tab=='CharacterNameFields'then E.select_weapon(main)end
  E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..tab..'-'..lang..'.bmp')
  if tab=='FontStyleFields'then E.ui.scroll=E.ui.last_page or 1;E.ui.row=#E.ui.weapon.rows;E.tick();assert(E.ui.last_visible==#E.ui.weapon.rows)end
 end
end
for _,p in ipairs(E.weapons_in('IdentityRpcInfo'))do
 assert(#p.rows==3)
 for _,r in ipairs(p.rows)do assert(r.empty and #r.parts==0 and r.readonly_text)end
end
gdi.DeleteDC(S.dc)
print('PASS: 91 character records / 364 fields, 6 font sets / 720 fields; isolated writes, flag width, integer checksum protection, authenticated builds, config/presets/reset, search, native navigation, bilingual render and bottom scrolling; RPC metadata read-only; no game writes')
]==]
assert(loadstring(start..checks,'@identity-parameters-integration'))()
