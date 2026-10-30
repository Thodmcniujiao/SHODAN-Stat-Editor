-- Exercise the actual click router, record parsers and renderer, using isolated real game data.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge',
 'SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,TYPES=TYPES,T_PROJECTILE=T_PROJECTILE,T_DAMAGE=T_DAMAGE,T_EXPLOSION=T_EXPLOSION,T_STATUS=T_STATUS,T_BEAM=T_BEAM,',1)
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
local R=E.MOD.references
for ref,kind in pairs(R.KINDS)do assert(E.tables[kind],ref..' table missing')end
local function find_row(w,id)
 for n,r in ipairs(w.rows)do if r.id==id then return r,n end end
 error('Missing row '..id)
end
local function double(w,row)
 E.ui.search.text='stale search that hides the target'
 E.select_weapon(w)
 if w.component_groups then
  for _,g in ipairs(w.component_groups)do E.ui.expanded_components[w.hash..':'..g.type]=true end
  w.sync_rows()
 end
 local n;for i,r in ipairs(w.rows)do if r==row or r.id==row.id and r.parts==row.parts then n=i end end;assert(n)
 local value=E.row_value(row);local writes=state.writes
 E.click('value:'..n)
 assert(E.ui.weapon==w,'single click navigated')
 assert(row.link_only or E.ui.value,'single click must retain numeric editing')
 E.click('value:'..n)
 assert(not E.ui.value,'double click left the source edit open')
 assert(state.writes==writes,'navigation must not write values')
 assert(E.ui.search.text=='','jump must clear a stale search')
 local target=E.ui.weapon
 assert(target~=w and target.id==value,'wrong target record')
 assert(E.ui.nav.page=='gamedata','wrong top-level page')
 return target
end
local orbital
for _,w in ipairs(E.weapons)do if w.stratagem and w.stratagem.family=='orbital'and w.by_id.barrage_projectile1 then orbital=w;break end end
assert(orbital)
for slot=1,8 do
 local row=orbital.by_id['barrage_projectile'..slot].row
 assert(R.type_of(row)=='projectile_id')
 local tip=R.tip(row,row.tip_of());assert(table.concat(tip,' '):find('projectile_id',1,true))
 E.ui.weapon=orbital;E.change(row,0,false,slot%2==0 and 223 or 149)
 local target=double(orbital,row)
 assert(target.kind==E.T_PROJECTILE and E.ui.tab=='RecProjectile')
 E.reset_row(orbital,row)
end
assert(#H.diff()==0)
-- Follow a real projectile -> explosion -> damage chain through the same click handler.
local shot,impact
for _,id in ipairs(E.MOD.records.ids(E.T_PROJECTILE))do
 local w=E.MOD.records.page(E.T_PROJECTILE,id)
 local r=w.by_id.impact_explosion.row;local id=E.row_value(r)
 if id and id>0 and E.tables[E.T_EXPLOSION].index[id]then shot,impact=w,r;break end
end
local explosion=double(assert(shot),assert(impact));assert(E.ui.tab=='RecExplosion')
local damage_ref=find_row(explosion,'damage_ref')
local damage=double(explosion,damage_ref);assert(damage.kind==E.T_DAMAGE and E.ui.tab=='RecDamage')
local shared=damage.by_id.damage.field
assert(explosion.by_id.damage.field==shared,'record navigation duplicated the underlying damage value')
E.ui.weapon=damage;local original=E.row_value(damage.by_id.damage.row)
E.change(damage.by_id.damage.row,0,false,original+1)
assert(E.row_value(explosion.by_id.damage.row)==original+1)
E.reset_row(damage,damage.by_id.damage.row);assert(#H.diff()==0)
E.ui.weapon=damage;E.change(damage.by_id.damage.row,0,false,original+7)
TEST_PRESETS_HELPER.save(E,damage,1);assert(E.save_config())
assert(read(I.home..'/config.txt'):find(damage.hash..' damage ',1,true),'new record prefix was not saved')
assert(E.MOD.records.find(damage.hash)==damage,'new record prefix cannot be restored')
E.reset_weapon(damage);TEST_PRESETS_HELPER.load(E,damage,1)
assert(E.row_value(damage.by_id.damage.row)==original+7)
E.reset_weapon(damage);assert(#H.diff()==0)
-- Every exposed integer reference uses semantic metadata, including weapon swaps, shrapnel and status slots.
local found={}
for _,w in ipairs(E.weapons)do for _,r in ipairs(w.rows)do
 local ref=R.type_of(r);local value=E.row_value(r)
 if ref and R.KINDS[ref]and not found[ref]and value and value>0 and E.tables[R.KINDS[ref]].index[value]then
  found[ref]={w=w,r=r}
 end
end end
for _,ref in ipairs({'projectile_id','explosion_id','damage_id','status_effect_id','arc_id','beam_id'})do
 local s=assert(found[ref],'no live source for '..ref)
 local target=double(s.w,s.r);assert(target.kind==R.KINDS[ref])
end
-- A damage amount is not an ID. Its single/double clicks retain normal input behavior.
E.select_weapon(damage);local _,n=find_row(damage,'damage')
E.click('value:'..n);E.click('value:'..n)
assert(E.ui.weapon==damage and E.ui.value and not R.type_of(damage.rows[n]));E.ui.value=nil
-- 0 and missing references do not select a different page or write anything.
local source_row=orbital.by_id.barrage_projectile8.row
E.ui.weapon=orbital;E.change(source_row,0,false,0);E.select_weapon(orbital)
local _,n=find_row(orbital,source_row.id);E.click('value:'..n);E.click('value:'..n)
assert(E.ui.weapon==orbital and E.ui.message and not E.ui.value)
E.reset_row(orbital,source_row)
assert(not R.open({reference_type='projectile_id',reference_value=function()return 999999 end}))
assert(E.ui.weapon==orbital)
-- An invalid pending input is retained; navigation must not discard it.
local _,n=find_row(orbital,'barrage_projectile1');E.select_weapon(orbital)
E.click('value:'..n);E.ui.value.text='invalid'
E.click('value:'..n)
assert(E.ui.weapon==orbital and E.ui.value and E.ui.value.text=='invalid')
E.ui.value=nil
-- The existing extra-stratagem IDs follow the same mechanism.
local extra
for _,w in ipairs(E.weapons)do if w.by_id.extra and E.row_value(w.by_id.extra.row)>0 then extra=w;break end end
if extra then
 E.select_weapon(extra);local r=extra.by_id.extra.row;local id=E.row_value(r)
 assert(R.type_of(r)=='stratagem_id'and R.open(r))
 local def=E.ui.weapon.stratagem_type and E.ui.weapon.def or E.ui.weapon.stratagem and E.ui.weapon.stratagem.def
 assert(def and tonumber(ffi.cast('uint32_t *',def.at)[0])==id)
end
-- Click pairing rejects another row/page, an expired interval and excessive pointer movement.
E.ui.reference_click=nil
assert(not R.double_click(orbital,1,10,1,1))
assert(not R.double_click(orbital,2,10.1,1,1))
assert(not R.double_click(shot,2,10.2,1,1))
assert(not R.double_click(shot,2,20,1,1))
assert(not R.double_click(shot,2,20.1,20,1))
assert(R.double_click(shot,2,20.2,20,1))
assert(#H.diff()==0)
-- Render badges, links, and the newly available record destinations through GDI.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
state.nav_open('orbitals',1);E.select_weapon(orbital);E.ui.message=nil
local _,n=find_row(orbital,'barrage_projectile1');E.ui.scroll=n-2;E.ui.row=n
E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/reference-badges.bmp')
for _,kind in ipairs({E.T_PROJECTILE,E.T_EXPLOSION,E.T_DAMAGE,E.T_STATUS,E.TYPES.arc,E.T_BEAM})do
 local id=assert(E.MOD.records.ids(kind)[1]);local page=E.MOD.records.page(kind,id)
 E.select_weapon(page);E.MOD.nav.sync();E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/record-'..page.hash:sub(1,2)..'.bmp')
end
gdi.DeleteDC(S.dc)
assert(E.save_config());local cfg=read(I.home..'/config.txt')
assert(not cfg:find('damage_id ',1,true)and not cfg:find('damage_ref ',1,true),'read-only links leaked into writable config')
assert(#H.diff()==0)
print('PASS: eight orbital slots; all six semantic reference types; actual single/double click routing; exact selection/search clearing; projectile -> explosion -> shared damage; 0/missing/ordinary values; click timing/page/row/movement; GDI badges and all record pages; no game writes')
]==]
assert(loadstring(start..checks,'@reference-navigation-integration'))()
