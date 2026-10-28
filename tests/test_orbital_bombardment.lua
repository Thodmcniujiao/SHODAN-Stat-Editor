-- Real game tables in isolated memory/profile: no installation or game file writes.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge',
    'SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,TYPES=TYPES,T_PROJECTILE=T_PROJECTILE,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs({'generated_projectile_settings.dl_bin','generated_stratagem_settings.dl_bin'})do
 local plain=read(TEST_FIXTURES..'/'..name)
 original[name]=G.seal(ffi.cast('const uint8_t *',plain),#plain)
end
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local O=E.MOD.orbital
assert(O.check_layout(model.schemas),'current game schema rejected')
assert(not O.check_layout({}),'missing schema must refuse expanded fields')
local schema=model.schemas[model.schemas[E.TYPES.bombard].members[2].type]
local size=schema.size;schema.size=184
assert(not O.check_layout(model.schemas),'changed layout must be refused')
schema.size=size
local page,count
count=0
for _,w in ipairs(E.weapons)do
 if w.stratagem and w.stratagem.family=='orbital'and w.by_id.barrage_shells then
  count=count+1;page=page or w
  for _,p in ipairs(O.PARAMS)do
   local actual=assert(w.by_id[p[1]],w.name..' missing '..p[2])
   assert(E.row_value(actual.row)~=nil,w.name..' unreadable '..p[2])
   assert(actual.row.tip_of()[1]:find(p[2],1,true))
  end
  local hash
  for _,r in ipairs(w.rows)do if r.readonly_text then hash=r.readonly_text end end
  assert(hash and #hash>=16,'exact decimal EntityHash missing')
 end
end
assert(count>=10,'orbital pages missing: '..count)
print('Orbital pages with all 28 writable fields:',count)
local t=E.tables[E.TYPES.bombard]
local base=page.by_id.barrage_initial_delay.field.offset
local address=t.copies[1]+24+base
local before=ffi.string(ffi.cast('const void *',address),192)
E.ui.weapon=page
-- Exercise every byte range, including signed values, the flag byte and all eight projectile slots.
for _,p in ipairs(O.PARAMS)do
 local row=page.by_id[p[1]].row
 local old=E.row_value(row)
 local value=p[4]=='flag'and(1-old)or p[4]=='u32'and 0 or p[5]<0 and -5 or 0.25
 if p[4]=='u32'and not p[2]:match('^ProjectileID')then value=23 end
 if p[2]:match('^ProjectileID')then
  value=old==149 and 223 or 149
  assert(E.tables[E.T_PROJECTILE].index[value],'test projectile missing')
 end
 E.change(row,0,false,value)
 assert(math.abs(E.row_value(row)-value)<1e-4,p[2]..' failed to edit')
 local bytes=ffi.string(ffi.cast('const void *',address),192)
 local length=p[4]=='flag'and 1 or 4
 assert(bytes:sub(1,p[3])==before:sub(1,p[3]),p[2]..' touched preceding bytes')
 assert(bytes:sub(p[3]+length+1)==before:sub(p[3]+length+1),p[2]..' touched following bytes')
 E.reset_row(page,row)
 assert(ffi.string(ffi.cast('const void *',address),192)==before,p[2]..' reset failed')
end
-- Persist negative delays and independent projectile pattern entries, then restore them together.
local initial=page.by_id.barrage_initial_delay.row
E.change(initial,0,false,-5)
E.change(page.by_id.barrage_start_delay.row,0,false,-2)
E.change(page.by_id.barrage_projectile8.row,0,false,0)
assert(E.save_config())
local cfg=read(I.home..'/config.txt')
assert(cfg:find(page.hash..' barrage_initial_delay -5',1,true))
assert(cfg:find(page.hash..' barrage_start_delay -2',1,true))
TEST_PRESETS_HELPER.save(E,page,1)
E.reset_weapon(page)
TEST_PRESETS_HELPER.load(E,page,1)
assert(E.row_value(initial)==-5 and E.row_value(page.by_id.barrage_start_delay.row)==-2)
E.reset_weapon(page)
assert(ffi.string(ffi.cast('const void *',address),192)==before)
assert(#H.diff()==0,'reset must restore every original game byte')
local projectile=page.by_id.barrage_projectile1.row
local old=E.row_value(projectile)
E.change(projectile,0,false,999999)
assert(E.row_value(projectile)==old and #H.diff()==0,'unknown projectile must be refused')
-- The live renderer must handle both parameter pages and the exact 64-bit hash without UI errors.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
state.nav_open('orbitals',1)
E.select_weapon(page)
for n,r in ipairs(page.rows)do if r.readonly_text then E.ui.row=n;E.ui.scroll=n end end
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/bombardment-top.bmp')
E.ui.row=#page.rows;E.ui.scroll=#page.rows-23;E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/bombardment-bottom.bmp')
gdi.DeleteDC(S.dc)
print('PASS: schema guard, 28 field values/isolated byte writes/reset, signed delays, one-byte flag, eight projectile slots, config and presets, GDI render; no game writes')
]==]
assert(loadstring(start..checks,'@orbital-bombardment-integration'))()
