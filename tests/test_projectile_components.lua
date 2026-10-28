-- Complete ProjectileInfo pages, using real current records and isolated host/editor state.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close()
local pre=assert(source:match('^(.-)local checks='))
pre=pre.."\nstart=start:gsub('MOD=MOD,','MOD=MOD,parse_rows=parse_rows,',1)\n"
local checks=[==[
local C=E.MOD.projectile.schema
assert(C.check_layout(model.schemas),'current ProjectileInfo layout rejected')
assert(not C.check_layout({}))
local record=model.schemas[model.schemas[E.T_PROJECTILE].members[1].type]
local original_size=record.size;record.size=280;assert(not C.check_layout(model.schemas));record.size=original_size
local old_count=record.members[53].count;record.members[53].count=9999;assert(not C.check_layout(model.schemas));record.members[53].count=old_count
local function find(w,field)
 for _,r in ipairs(w.rows)do if r.tip_of and r.tip_of()[1]==field then return r end end
 error(w.name..' missing '..field)
end
local ids=E.MOD.records.ids(E.T_PROJECTILE);assert(#ids>=355)
local expected=#C.FIELDS+#C.BITS;assert(expected==73)
for _,id in ipairs(ids)do
 local w=E.MOD.records.page(E.T_PROJECTILE,id);assert(#w.rows==expected,w.name..' wrong row count')
 for _,s in ipairs(C.FIELDS)do
  local r=find(w,s[1]);assert(r.component=='ProjectileType')
  if r.hash64 then assert(E.MOD.stratagem.hash_text(r):match('^%d+$'))else assert(E.row_value(r)~=nil,w.name..' unreadable '..s[1])end
  for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')end
 end
 for _,s in ipairs(C.BITS)do local v=E.row_value(find(w,s[1]));assert(v==0 or v==1)end
 for _,r in ipairs(w.rows)do for _,p in ipairs(r.parts)do assert(p.field.kind==E.T_PROJECTILE,'referenced component expanded inline')end end
end
print('Verified projectile records / full fields per record:',#ids,expected)
-- Optional reference flattened to TSV by Python, preserving all uint64 decimal strings.
local reference=os.getenv('SHODAN_PROJECTILE_REFERENCE_TSV')
if reference then
 local f=assert(io.open(reference,'rb'));local compared,equal=0,0;local changed={}
 for line in f:lines()do
  line=line:gsub('\r$','')
  local id,name,text=line:match('^(%d+)\t([^\t]+)\t(.+)$')
  if id then
   local w=E.MOD.records.page(E.T_PROJECTILE,tonumber(id))
   if w then
    local r=find(w,name);local ok
    if r.hash64 then ok=E.MOD.stratagem.hash_text(r)==text
    else local v=E.row_value(r);local target=tonumber(text);ok=math.abs(v-target)<=math.max(1e-6,math.abs(target)*1e-6)end
    compared=compared+1;if ok then equal=equal+1 else changed[name]=(changed[name]or 0)+1 end
   end
  end
 end
 f:close()
 print('Reference field comparisons / equal:',compared,equal)
 for name,n in pairs(changed)do print('Version differences:',name,n)end
 assert(compared>=355*73 and equal/compared>.95,'reference/current mismatch: '..equal..'/'..compared)
end
local w=E.MOD.records.page(E.T_PROJECTILE,ids[1]);E.ui.weapon=w
local at=E.tables[E.T_PROJECTILE].index[w.id];local base=E.tables[E.T_PROJECTILE].copies[1]+24+at
local function bytes()return ffi.string(ffi.cast('const void *',base),C.SIZE)end
local original=bytes()
for _,s in ipairs(C.FIELDS)do if s[3]~='id'and s[3]~='u64'and not s[8]then
 local r=find(w,s[1]);local off,size=s[2],s[3]=='u16'and 2 or s[3]=='u8'and 1 or s[3]:match('^bit')and 1 or 4
 local old=E.row_value(r);local target=r.storage=='flag'and(1-old)or s[4]=='attachment'and -2.5 or old==0 and 1 or 0
 E.change(r,0,false,target);assert(math.abs(E.row_value(r)-target)<1e-5,s[1]..' edit failed')
 local now=bytes();assert(now:sub(1,off)==original:sub(1,off),s[1]..' touched previous bytes')
 assert(now:sub(off+size+1)==original:sub(off+size+1),s[1]..' touched following bytes')
 E.reset_row(w,r);assert(bytes()==original,s[1]..' reset failed')
end end
-- life_time is +52; the old page mistakenly edited randomness at +56.
assert(find(w,'life_time').parts[1].field.offset==at+52)
assert(find(w,'life_time_randomness').parts[1].field.offset==at+56)
E.change(find(w,'life_time'),0,false,7);E.change(find(w,'life_time_randomness'),0,false,3)
assert(E.row_value(find(w,'life_time'))==7 and E.row_value(find(w,'life_time_randomness'))==3)
E.reset_weapon(w);assert(bytes()==original)
-- Raw packed values and bit switches share one canonical config/preset value.
local raw=find(w,'projectile_flags_1');E.change(raw,0,false,65535)
for _,s in ipairs(C.BITS)do if s[2]==244 then
 local r=find(w,s[1]);assert(E.row_value(r)==1)
 E.change(r,0,false,0);assert(E.row_value(raw)==65535-2^s[3])
 E.change(r,0,false,1);assert(E.row_value(raw)==65535)
end end
E.reset_row(w,raw)
for _,s in ipairs(C.BITS)do
 local r=find(w,s[1]);local aggregate=find(w,s[2]==244 and'projectile_flags_1'or'projectile_flags_2')
 local value=E.row_value(aggregate);local old=E.row_value(r)
 E.change(r,0,false,1-old);assert(E.row_value(aggregate)==value+(old==0 and 1 or -1)*2^s[3])
 E.reset_row(w,r);assert(E.row_value(aggregate)==value)
end
assert(bytes()==original)
E.change(raw,0,false,65535)
E.change(find(w,'project_decal'),0,false,0);E.change(find(w,'can_pass_through_shield'),0,false,0)
local expected_flags=65535-64-1024
assert(E.row_value(raw)==expected_flags)
E.presets.save_weapon_preset(w,2)
local preset=E.presets.weapon_preset(w,2);local count=0
for _,v in ipairs(preset)do if v.id=='projectile_flags_1'then count=count+1;assert(v.value==expected_flags)end end
assert(count==1,'packed bit views duplicated the canonical preset value')
E.reset_weapon(w);assert(bytes()==original)
E.presets.load_weapon_preset(w,2);assert(E.row_value(raw)==expected_flags)
assert(E.row_value(find(w,'project_decal'))==0 and E.row_value(find(w,'can_pass_through_shield'))==0)
E.reset_weapon(w);assert(bytes()==original)
-- Exact decimal hashes, including the maximum and bit patterns resembling floats.
for _,s in ipairs(C.FIELDS)do if s[3]=='u64' then
 local r=find(w,s[1]);assert(E.MOD.stratagem.set_hash(w,r,'18446744073709551615'))
 assert(E.MOD.stratagem.hash_text(r)=='18446744073709551615');E.reset_row(w,r);assert(bytes()==original)
end end
local hash=find(w,'hud_icon');assert(not E.MOD.stratagem.set_hash(w,hash,'18446744073709551616'))
assert(E.MOD.stratagem.set_hash(w,hash,'4593671620989558785'))
E.change(find(w,'audio_crack_event'),0,false,1069547521) -- an integer that resembles a finite float
local expected_bytes=bytes();local staged=H.diff();assert(#staged==1 and #staged[1].floats==0,'hash/ID bits offered as float correction salt')
local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
local verified
for _,h in ipairs(G.headers(plain,n))do if h.type==E.T_PROJECTILE then
 local p=plain+h.at+24;local count=tonumber(ffi.cast('uint32_t *',p+8)[0])
 for i=0,count-1 do local r=p+16+i*C.SIZE
  if tonumber(ffi.cast('uint32_t *',r)[0])==w.id then assert(ffi.string(r,C.SIZE)==expected_bytes);verified=true end
 end
 -- The parser also accepts authenticated correction bytes following the fixed array.
 local before=E.tables[E.T_PROJECTILE].entries
 local blob=ffi.string(p,h.size)
 local index,entries=E.parse_rows(blob,C.SIZE,{tail=true})
 assert(index and entries==before and index[w.id]==at,'appended correction bytes broke record parsing')
 assert(h.size>16+count*C.SIZE and not E.parse_rows(blob,C.SIZE,{}),'fixture did not exercise a grown table')
end end
assert(verified);G.free(plain)
E.presets.save_weapon_preset(w,1);assert(E.save_config())
assert(read(I.home..'/config.txt'):find('hud_icon_lo ',1,true))
E.reset_weapon(w);assert(bytes()==original)
E.presets.load_weapon_preset(w,1);assert(bytes()==expected_bytes);E.reset_weapon(w);assert(bytes()==original)
-- Editing and jumping use the same typed damage/explosion references, with no inline records.
local function double(row)
 E.select_weapon(w);local index;for i,r in ipairs(w.rows)do if r==row then index=i end end
 local writes=state.writes;E.click('value:'..index);E.click('value:'..index);assert(state.writes==writes)
 return E.ui.weapon
end
for _,name in ipairs({'damage_info_type','explosion_type_on_impact','explosion_type_expire'})do
 local r=find(w,name);local kind=E.MOD.references.KINDS[r.reference_type];local id=E.MOD.records.ids(kind)[1]
 E.ui.weapon=w;E.change(r,0,false,id);assert(E.row_value(r)==id)
 local target=double(r);assert(target.kind==kind and target.id==id)
 E.ui.weapon=w;E.change(r,0,false,4294967295);assert(E.row_value(r)==id,'missing referenced ID accepted')
 E.reset_row(w,r)
end
assert(not E.MOD.references.type_of(find(w,'effect_damage_type')))
assert(not E.MOD.references.type_of(find(w,'status_effect_volume_template')))
local damage_id=E.row_value(find(w,'damage_info_type'))
local related=E.MOD.records.page(E.T_DAMAGE,damage_id);local damage=related.by_id.damage.row;local old=E.row_value(damage)
E.ui.weapon=related;E.change(damage,0,false,old+1);E.reset_weapon(w)
assert(E.row_value(damage)==old+1,'projectile reset followed a reference into another component')
E.reset_row(related,damage)
assert(bytes()==original and #H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil;E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/projectile-'..lang..'-top.bmp')
 for _,field in ipairs({'hud_icon','projectile_flags_1','projectile_attachment_local_offset.x'})do
  local r=find(w,field);for i,x in ipairs(w.rows)do if x==r then E.ui.scroll=math.max(1,i-2);E.ui.row=i end end
  E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/projectile-'..lang..'-'..field..'.bmp')
 end
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(E.ui.last_visible==#w.rows)
end
gdi.DeleteDC(S.dc);assert(#H.diff()==0)
print('PASS: all current 272-byte ProjectileInfo records; 73 bilingual fields; exact uint64 hashes; independent lifetime/randomness; packed flag preservation/canonical presets; typed references; authenticated build/readback; complete replacement, GDI and scrolling; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@projectile-components-integration"))()'))()
