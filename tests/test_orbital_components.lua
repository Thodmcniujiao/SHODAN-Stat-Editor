-- Full OrbitalAbility records, actual editor controls and authenticated output; isolated profile, no game writes.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close()
local pre=assert(source:match('^(.-)local checks='))
pre=pre.."\nstart=start:gsub('MOD=MOD,','MOD=MOD,T_ORBITAL=T_ORBITAL,',1)\n"
local checks=[==[
local C=require('orbital_components').SPECS[1]
local V=require('component_view')
assert(C.SIZE==568 and V.check_layout(C,model.schemas,C.HASH))
assert(not V.check_layout(C,{},C.HASH))
local native=model.schemas[model.schemas[C.HASH].members[2].type]
native.size=552;assert(not V.check_layout(C,model.schemas,C.HASH));native.size=568
-- The reference INI's 19 editable fields, plus all fields omitted by that menu.
local wanted={pattern_segments=true,smooth_segments=true,segment_pause=true,duration=true,remove_time=true,
 movement_speed=true,search_radius=true,['damage_dealer_zone.damage_info_type']=true,
 ['damage_dealer_zone.interval']=true,['damage_dealer_zone.shape']=true,
 ['damage_dealer_zone.size.x']=true,['damage_dealer_zone.size.y']=true,['damage_dealer_zone.size.z']=true,
 surface_impact=true,ship_effect_is_laser_pointer=true,projectile_type=true,projectile_spawn_height=true,
 projectile_spawn_delay=true,target_list_update_time=true}
local names,points,spans={},0,{}
for _,s in ipairs(C.FIELDS)do
 assert(not names[s[1]],s[1]);names[s[1]]=s;wanted[s[1]]=nil
 if s[1]:match('^pattern_control_points')then points=points+1 end
 local size=s[3]=='u64'and 8 or(s[3]=='flag'or s[3]=='u8')and 1 or 4
 assert(s[2]+size<=C.SIZE)
 for off=s[2],s[2]+size-1 do assert(not spans[off],s[1]..' overlap');spans[off]=true end
end
assert(not next(wanted)and points==112)
local pages=E.weapons_in('OrbitalBeam');assert(#pages==2,#pages)
local values={'entity\tfield\tvalue'}
for _,w in ipairs(pages)do
 assert(w.orbital_full,w.name..' did not use the full component')
 assert(#w.rows==#C.FIELDS+1,w.name..' missing rows: '..#w.rows)
 assert(w.rows[1].readonly_text==E.MOD.orbital.decimal(w.key))
 E.ui.weapon=w
 local base=E.tables[E.T_ORBITAL].copies[1]+24+E.tables[E.T_ORBITAL].index[w.key]
 local function bytes()return ffi.string(ffi.cast('const void *',base),C.SIZE)end
 local original=bytes()
 for _,s in ipairs(C.FIELDS)do
  local r;for _,candidate in ipairs(w.rows)do if candidate.id==s[9].id then r=candidate;break end end
  assert(r,s[1])
  assert(r.tip_of()[1]==s[1])
  local old=r.hash64 and E.MOD.stratagem.hash_text(r)or E.row_value(r)
  assert(old~=nil,w.name..' unreadable '..s[1])
  values[#values+1]=w.hash..'\t'..s[1]..'\t'..tostring(old)
  for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do
   E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')
  end
  local target
  if r.hash64 then assert(E.MOD.stratagem.set_hash(w,r,'18446744073709551615'))
  else
   target=old==0 and 1 or 0
   if s[3]=='f32'then target=r.min<0 and -0.25 or 0.25 end
   if s[9].ref then target=E.MOD.records.ids(E.MOD.references.KINDS[s[9].ref])[1]end
   E.change(r,0,false,target)
   assert(E.row_value(r)==target,s[1]..' edit failed')
  end
  local size=s[3]=='u64'and 8 or(s[3]=='flag'or s[3]=='u8')and 1 or 4
  local now=bytes()
  assert(now:sub(1,s[2])==original:sub(1,s[2])and now:sub(s[2]+size+1)==original:sub(s[2]+size+1),s[1]..' changed adjacent bytes')
  E.reset_row(w,r);assert(bytes()==original,s[1]..' reset failed')
 end
end
write(TEST_WORK..'/orbital-values.tsv',table.concat(values,'\n'))
local w=pages[1];E.ui.weapon=w
local function row(name)
 for _,r in ipairs(w.rows)do if r.id==assert(names[name])[9].id then return r end end
 error(name)
end
E.change(row('duration'),0,false,31)
E.change(row('pattern_control_points[55].y'),0,false,-123.5)
E.change(row('factions[3].faction'),0,false,8)
assert(E.MOD.stratagem.set_hash(w,row('ship_effect'),'4593671620989558785'))
local base=E.tables[E.T_ORBITAL].copies[1]+24+E.tables[E.T_ORBITAL].index[w.key]
local expected=ffi.string(ffi.cast('const void *',base),C.SIZE)
assert(E.save_config());TEST_PRESETS_HELPER.save(E,w,1)
local config=read(I.home..'/config.txt')
assert(config:find(w.hash..' beam_duration 31',1,true),'legacy page hash/id changed')
assert(config:find(w.hash..' pattern_control_points_55__y -123.5',1,true))
E.reset_weapon(w);TEST_PRESETS_HELPER.load(E,w,1)
assert(ffi.string(ffi.cast('const void *',base),C.SIZE)==expected,'preset did not restore full record')
-- Build and decrypt the resulting entity file in memory, checking the record and original checksum.
local diff=H.diff();assert(#diff==1 and diff[1].name=='generated_entities.dl_bin')
local cipher,why=H.build(diff[1]);assert(cipher,why)
local plain,n=G.open_sealed(cipher);assert(plain and G.murmur64(plain,n)==diff[1].hash)
local offset=base-tonumber(ffi.cast('uintptr_t',H.files['generated_entities.dl_bin'].p))
assert(ffi.string(plain+offset,C.SIZE)==expected,'built file differs from the edited record');G.free(plain)
E.reset_weapon(w);assert(#H.diff()==0)
-- Both typed links retain single-click numeric editing and double-click navigation.
for _,name in ipairs({'damage_dealer_zone.damage_info_type','projectile_type'})do
 local r=row(name);local ref=names[name][9].ref
 local target=E.MOD.records.ids(E.MOD.references.KINDS[ref])[1]
 E.ui.weapon=w;E.change(r,0,false,target)
 E.select_weapon(w);local at;for i,x in ipairs(w.rows)do if x==r then at=i end end
 local writes=state.writes;E.click('value:'..at);assert(E.ui.value)
 E.click('value:'..at);assert(E.ui.weapon.id==target and state.writes==writes)
 E.ui.weapon=w;E.change(r,0,false,4294967295);assert(E.row_value(r)==target)
 E.reset_row(w,r)
end
assert(#H.diff()==0)
-- Render the exact target subpage, including every control point at the bottom.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.click('set:lang:'..lang);S.lang=function()return E.settings.lang end
 E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil;E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/orbital-'..lang..'-top.bmp')
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(E.ui.last_visible==#w.rows)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/orbital-'..lang..'-bottom.bmp')
end
gdi.DeleteDC(S.dc)
print('PASS: '..#pages..' orbital entities, '..#C.FIELDS..' fields each; 19 INI fields; all 112 XY coordinates; byte boundaries; exact u64; config/preset/reset; typed links; authenticated entity build; bilingual render and bottom scrolling; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@orbital-components-integration"))()'))()
