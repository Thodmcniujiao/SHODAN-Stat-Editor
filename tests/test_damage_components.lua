-- Real current records and editor controls. Isolated profile/buffers; never installs game files.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close()
local pre=assert(source:match('^(.-)local checks='))
local checks=[==[
local C=E.MOD.damage.schema
assert(C.check_layout(model.schemas),'current DamageInfo schema rejected')
assert(not C.check_layout({}),'unknown layouts must not open new fields')
local typ=model.schemas[E.T_DAMAGE].members[1].type
local old=model.schemas[typ].size;model.schemas[typ].size=80
assert(not C.check_layout(model.schemas));model.schemas[typ].size=old
local required={'DamageTypeID','Damage','ArmorDamage','PenetrationAngle25','PenetrationAngle60',
 'PenetrationAngle80','PenetrationAngle90','Demolition','ForceStrength','ForceImpulse','ElementType',
 'StatusEffectType1','StatusEffectFactor1','StatusEffectType2','StatusEffectFactor2',
 'StatusEffectType3','StatusEffectFactor3','StatusEffectType4','StatusEffectFactor4'}
local total,instances,enemies,slots=0,0,0,{}
local function inspect(w)
 if w.record and w.kind==E.T_DAMAGE then assert(#w.rows==19,'damage ID page expanded a referenced component')end
 local groups={}
 for _,r in ipairs(w.rows)do
  if r.component and r.component:match('^DamageType:')then
   assert(not w.enemy,'enemy UI changed')
   local g=groups[r.component]or{};groups[r.component]=g
   local name=r.tip_of()[1];assert(not g[name],w.name..' duplicate '..name);g[name]=r
   assert(E.row_value(r)~=nil,w.name..' unreadable '..name)
   for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do
    E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')
   end
  else
   for _,p in ipairs(r.parts)do assert(w.enemy or p.field.kind~=E.T_DAMAGE,w.name..' has an old partial damage/status row: '..r.id)end
  end
 end
 for _,g in pairs(groups)do
  instances=instances+1
  for _,name in ipairs(required)do assert(g[name],w.name..' missing '..name)end
  local n=0;for _ in pairs(g)do n=n+1 end;assert(n==19)
 end
 total=total+1
end
for _,w in ipairs(E.weapons)do inspect(w);if w.enemy then enemies=enemies+1 end end
for _,kind in ipairs(E.MOD.records.KINDS)do
 for _,id in ipairs(E.MOD.records.ids(kind))do inspect(E.MOD.records.page(kind,id))end
end
assert(instances>100 and enemies>100)
print('Verified pages / complete DamageType instances / unchanged enemy pages:',total,instances,enemies)
local raw=assert(E.MOD.records.page(E.T_DAMAGE,141))
local acid=assert(E.MOD.records.page(E.T_DAMAGE,1))
assert(#acid.rows==19 and E.row_value(acid.by_id.slot1.row)==11)
local writes=state.writes
E.select_weapon(acid)
local index;for i,r in ipairs(acid.rows)do if r==acid.by_id.slot1.row then index=i end end
E.click('value:'..index);E.click('value:'..index)
assert(E.ui.weapon.kind==E.T_STATUS and E.ui.weapon.id==11,'status reference did not jump')
local status=E.ui.weapon
for i,r in ipairs(status.rows)do if r.id=='damage_ref'then index=i end end
E.click('value:'..index);E.click('value:'..index)
assert(E.ui.weapon.kind==E.T_DAMAGE and E.ui.weapon.id==534 and #E.ui.weapon.rows==19)
assert(state.writes==writes,'reference navigation wrote data')
local related=E.ui.weapon;local related_row=related.by_id.damage.row;local related_value=E.row_value(related_row)
E.change(related_row,0,false,related_value+1);E.reset_weapon(acid)
assert(E.row_value(related_row)==related_value+1,'reset followed a hidden status reference')
E.reset_row(related,related_row)
local at=assert(E.tables[E.T_DAMAGE].index[141]);local base=E.tables[E.T_DAMAGE].copies[1]+24+at
local function bytes()return ffi.string(ffi.cast('const void *',base),76)end
local original=bytes()
local function by(name)
 for _,r in ipairs(raw.rows)do if r.tip_of and r.tip_of()[1]==name then return r end end
 error('missing '..name)
end
for _,spec in ipairs(C.FIELDS)do
 local r=by(spec[2]);local before=bytes();local v=E.row_value(r)
 local target=spec[5]<0 and -5 or spec[2]=='ElementType'and 3 or v==0 and 1 or 0
 E.ui.weapon=raw;E.change(r,0,false,target);assert(E.row_value(r)==target,spec[2])
 local now=bytes();assert(now:sub(1,spec[3])==before:sub(1,spec[3]))
 assert(now:sub(spec[3]+5)==before:sub(spec[3]+5),spec[2]..' touched other fields')
 E.reset_row(raw,r);assert(bytes()==original)
end
-- All loaded statuses, including those absent from the old suggested list; ordered slots still enforced.
for i=4,1,-1 do E.change(by('StatusEffectType'..i),0,false,0)end
local none=bytes();local kind
for _,id in ipairs(E.MOD.records.ids(E.T_STATUS))do if not E.MOD.status.by[id]then kind=id;break end end
assert(kind)
E.change(by('StatusEffectType2'),0,false,kind);assert(E.row_value(by('StatusEffectType2'))==0,'status gap allowed')
E.change(by('StatusEffectType1'),0,false,kind);assert(E.row_value(by('StatusEffectType1'))==kind)
assert(E.row_value(by('StatusEffectFactor1'))~=0,'new status got zero strength')
E.change(by('StatusEffectType2'),0,false,kind)
E.change(by('StatusEffectType1'),0,false,0);assert(E.row_value(by('StatusEffectType1'))==kind,'clearing before populated slot allowed')
E.change(by('StatusEffectType2'),0,false,0)
E.change(by('StatusEffectType1'),0,false,999999);assert(E.row_value(by('StatusEffectType1'))==kind,'missing status accepted')
E.change(by('StatusEffectFactor1'),0,false,12.75);assert(E.row_value(by('StatusEffectFactor1'))==12.75)
local status_page=E.MOD.records.page(E.T_STATUS,kind)
assert(E.MOD.references.open(by('StatusEffectType1'))and E.ui.weapon==status_page)
E.ui.weapon=raw
E.change(by('Damage'),0,false,1234);E.change(by('ElementType'),0,false,5)
TEST_PRESETS_HELPER.save(E,raw,1);assert(E.save_config())
local cfg=read(I.home..'/config.txt');assert(cfg:find('element_type 5',1,true))
assert(not cfg:find('damage_id ',1,true),'record identity was saved as editable data')
local staged=H.diff();assert(#staged==1 and staged[1].name=='generated_damage_settings.dl_bin')
local expected=bytes();local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
local verified
for _,h in ipairs(G.headers(plain,n))do if h.type==E.T_DAMAGE then
 local p=plain+h.at+24;local ptr=tonumber(ffi.cast('uint64_t *',p)[0]);local count=tonumber(ffi.cast('uint32_t *',p+8)[0])
 for i=0,count-1 do local row=p+ptr+i*76
  if tonumber(ffi.cast('uint32_t *',row)[0])==141 then assert(ffi.string(row,76)==expected,'authenticated build changed damage record');verified=true end
 end
end end
assert(verified);G.free(plain)
E.reset_weapon(raw);assert(bytes()==original)
TEST_PRESETS_HELPER.load(E,raw,1);assert(bytes()==expected,'preset round trip')
E.reset_weapon(raw);assert(bytes()==original and #H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
local gun,flame,throwable,orbital,heat
for _,w in ipairs(E.weapons)do if not w.enemy then
 if w.name:find('Liberator',1,true)and w.by_id.element_type then gun=gun or w end
 if w.by_id.status5_damage then flame=flame or w end
 if w.slot=='Throwables'and w.by_id.x_element_type then throwable=throwable or w end
 if w.stratagem and w.stratagem.family=='eagle'and w.by_id.d1_element_type then orbital=orbital or w end
 if w.by_id.heatlvl1_self_damage then heat=heat or w end
end end
assert(gun and flame and heat)
for _,pair in ipairs({{'raw',raw},{'raw-acid',acid},{'gun',gun},{'flame',flame},{'heat',heat}})do
 local w=pair[2];E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil
 E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/damage-'..pair[1]..'.bmp')
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(state.ui_errors==0)
 assert(E.ui.last_visible==#w.rows,'last row unreachable')
end
gdi.DeleteDC(S.dc);assert(#H.diff()==0)
print('PASS: 76-byte schema and all 19 fields everywhere except enemy UI; signed damage; byte boundaries; all status IDs/order/navigation; old stat keys; config/presets; authenticated build/readback; nested headings/GDI/last-row reachability; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@damage-components-integration"))()'))()
