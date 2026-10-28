-- Full current ExplosionInfo records, with the old decrypted definitions as name/field reference.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close()
local pre=assert(source:match('^(.-)local checks='))
local checks=[==[
local C=E.MOD.explosion.schema;local X=E.MOD.explosion
assert(C.check_layout(model.schemas),'current 152-byte ExplosionInfo rejected')
assert(not C.check_layout({}))
local native=model.schemas[model.schemas[E.T_EXPLOSION].members[1].type]
assert(#native.members==40)
local size=native.size;native.size=160;assert(not C.check_layout(model.schemas));native.size=size
local off=native.members[13].offset;native.members[13].offset=69;assert(not C.check_layout(model.schemas));native.members[13].offset=off
local function find(w,name)
 for _,r in ipairs(w.rows)do if r.tip_of and r.tip_of()[1]==name then return r end end
 error(w.name..' missing '..name)
end
local known={};for _,s in ipairs(C.FIELDS)do known[s[1]]=true end;for _,s in ipairs(C.BITS)do known[s[1]]=true end
local reference=os.getenv('SHODAN_EXPLOSION_LEGACY_FIELDS')
if reference then
 local f=assert(io.open(reference,'rb'));local count=0
 for name in f:lines()do name=name:gsub('\r$','');if name~=''then assert(known[name],'old decrypted field missing: '..name);count=count+1 end end
 f:close();assert(count==28);print('Old decrypted fields covered:',count)
end
local count=0;for _,field in pairs(C.LEGACY)do assert(known[field]);count=count+1 end;assert(count==12)
local ids=E.MOD.records.ids(E.T_EXPLOSION);assert(#ids>=424)
local total,largest,chosen,arc_page=0,-1,nil,nil
local output={}
for _,id in ipairs(ids)do
 local w=E.MOD.records.page(E.T_EXPLOSION,id);local at=E.tables[E.T_EXPLOSION].index[id]
 local target,n=assert(X.shakes(at));assert(n~=nil)
 assert(#w.rows==#C.FIELDS+#C.BITS+n,'wrong own-component field count')
 if n>largest then largest,chosen=n,w end
 if E.row_value(find(w,'arc_type'))>0 then arc_page=arc_page or w end
 for _,s in ipairs(C.FIELDS)do
  local r=find(w,s[1]);assert(r.component=='ExplosionType')
  local value=r.hash64 and E.MOD.stratagem.hash_text(r)or r.readonly_text or E.row_value(r)
  assert(value~=nil,w.name..' unreadable '..s[1])
  output[#output+1]=id..'\t'..s[1]..'\t'..tostring(value)
  for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')end
 end
 for _,s in ipairs(C.BITS)do local r=find(w,s[1]);local v=E.row_value(r);assert(v==0 or v==1);output[#output+1]=id..'\t'..s[1]..'\t'..v end
 for i=1,n do local r=find(w,'shake_assets['..i..']');assert(r.hash64)
  output[#output+1]=id..'\tshake_assets['..i..']\t'..E.MOD.stratagem.hash_text(r)
 end
 for _,r in ipairs(w.rows)do for _,p in ipairs(r.parts)do assert(p.field.kind==E.T_EXPLOSION,'another component expanded inline')end end
 total=total+#w.rows
end
write(TEST_WORK..'/current-explosion-values.tsv',table.concat(output,'\n'))
assert(largest>=2 and arc_page)
print('Current explosion records / fixed fields / array elements / all displayed fields:',#ids,#C.FIELDS+#C.BITS,total-#ids*(#C.FIELDS+#C.BITS),total)
local w=chosen;E.ui.weapon=w
local at=E.tables[E.T_EXPLOSION].index[w.id];local base=E.tables[E.T_EXPLOSION].copies[1]+24+at
local function bytes()return ffi.string(ffi.cast('const void *',base),C.SIZE)end
local original=bytes()
for _,s in ipairs(C.FIELDS)do if s[3]~='id'and s[3]~='u64'and s[3]~='array'and not s[8]then
 local r=find(w,s[1]);local off=s[2];local size=(s[3]=='u8'or s[3]=='i8'or s[3]:match('^bit'))and 1 or 4
 local old=E.row_value(r);local value=r.storage=='flag'and(1-old)or s[3]=='i8'and -2 or old==0 and 1 or 0
 E.change(r,0,false,value);assert(E.row_value(r)==value,s[1]..' edit failed')
 local now=bytes();assert(now:sub(1,off)==original:sub(1,off),s[1]..' touched previous bytes')
 assert(now:sub(off+size+1)==original:sub(off+size+1),s[1]..' touched following bytes')
 E.reset_row(w,r);assert(bytes()==original)
end end
for _,s in ipairs(C.FIELDS)do if s[3]=='u8'and(s[2]==116 or s[2]==124 or s[2]==132 or s[2]==140)then
 local raw=find(w,s[1]);E.change(raw,0,false,255)
 for _,b in ipairs(C.BITS)do if b[2]==s[2]then
  local bit=find(w,b[1]);E.change(bit,0,false,0);assert(E.row_value(raw)==255-2^b[3],'packed bit touched another flag')
  E.change(bit,0,false,1);assert(E.row_value(raw)==255)
 end end
 E.reset_row(w,raw)
end end
assert(bytes()==original)
-- The structural count is read-only; offsets/counts must stay within the owning table.
local count=find(w,'shake_assets');local writes=state.writes;E.change(count,0,false,20);assert(state.writes==writes)
local old_ptr=ffi.new('uint8_t[16]');ffi.copy(old_ptr,ffi.cast('const void *',base+40),16)
ffi.cast('uint32_t *',base+48)[0]=4097;assert(not X.shakes(at))
ffi.copy(ffi.cast('void *',base+40),old_ptr,16)
ffi.cast('uint64_t *',base+40)[0]=1;assert(not X.shakes(at),'array pointer inside records accepted')
ffi.copy(ffi.cast('void *',base+40),old_ptr,16);assert(X.shakes(at))
-- Scalar and dynamic-array resource hashes are exact; writing an array element changes only its 8 bytes.
local asset=find(w,'shake_assets[1]');local p=asset.parts[1].field
local file=H.files['generated_explosion_settings.dl_bin'];local file_before=ffi.string(file.p,file.n)
assert(E.MOD.stratagem.set_hash(w,asset,'18446744073709551615'))
assert(E.MOD.stratagem.hash_text(asset)=='18446744073709551615')
local global=(E.tables[E.T_EXPLOSION].copies[1]-tonumber(ffi.cast('uintptr_t',file.p)))+24+p.offset
local now=ffi.string(file.p,file.n);assert(now:sub(1,global)==file_before:sub(1,global)and now:sub(global+9)==file_before:sub(global+9))
E.reset_row(w,asset);assert(ffi.string(file.p,file.n)==file_before)
local hash=find(w,'particle_effect_path');assert(E.MOD.stratagem.set_hash(w,hash,'18446744073709551615'))
assert(E.MOD.stratagem.hash_text(hash)=='18446744073709551615');E.reset_row(w,hash)
assert(not E.MOD.stratagem.set_hash(w,hash,'18446744073709551616'))
assert(E.MOD.stratagem.set_hash(w,hash,'4593671620989558785'))
assert(E.MOD.stratagem.set_hash(w,asset,'4593671620989558785'))
E.change(find(w,'audio_event'),0,false,1069547521)
E.change(find(w,'explosion_flags'),0,false,255);E.change(find(w,'do_knockback'),0,false,0)
local expected=ffi.string(file.p,file.n)
E.presets.save_weapon_preset(w,1);assert(E.save_config())
local preset=E.presets.weapon_preset(w,1);local flags=0
for _,v in ipairs(preset)do if v.id=='explosion_flags'then flags=flags+1;assert(v.value==254)end end
assert(flags==1,'packed views duplicated the preset')
local staged=H.diff();assert(#staged==1 and #staged[1].floats==0,'uint64/ID bits used as float correction salt')
local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
-- The authenticated builder preserves all bytes of the original-sized data, except its container size.
for _,h in ipairs(G.headers(plain,n))do if h.type==E.T_EXPLOSION then
 local P=h.at+24;assert(ffi.string(plain+P,file.n-P)==expected:sub(P+1),'builder changed explosion values or array hashes')
end end
G.free(plain)
E.reset_weapon(w);assert(ffi.string(file.p,file.n)==file_before)
E.presets.load_weapon_preset(w,1);assert(ffi.string(file.p,file.n)==expected)
E.reset_weapon(w);assert(ffi.string(file.p,file.n)==file_before)
local function double(page,row)
 E.select_weapon(page);local index;for i,r in ipairs(page.rows)do if r==row then index=i end end
 local writes=state.writes;E.click('value:'..index);E.click('value:'..index);assert(state.writes==writes)
 return E.ui.weapon
end
for _,name in ipairs({'damage_type','shrapnel_projectile_type','arc_type'})do
 local r=find(w,name);local kind=E.MOD.references.KINDS[r.reference_type];local id=E.MOD.records.ids(kind)[1]
 E.ui.weapon=w;E.change(r,0,false,id);assert(E.row_value(r)==id)
 local target=double(w,r);assert(target.kind==kind and target.id==id)
 E.ui.weapon=w;E.change(r,0,false,4294967295);assert(E.row_value(r)==id)
 E.reset_row(w,r)
end
assert(not E.MOD.references.type_of(find(w,'persistent_status_volume')))
assert(not E.MOD.references.type_of(find(w,'hit_effect_damage_type')))
local related=E.MOD.records.page(E.T_DAMAGE,E.row_value(find(w,'damage_type')))
local damage=related.by_id.damage.row;local old=E.row_value(damage)
E.ui.weapon=related;E.change(damage,0,false,old+1);E.reset_weapon(w)
assert(E.row_value(damage)==old+1,'explosion reset followed damage reference');E.reset_row(related,damage)
assert(#H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil;E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/explosion-'..lang..'-top.bmp')
 for _,field in ipairs({'particle_effect_path','explosion_flags','arc_type','unk_enum_0x0090'})do
  local r=find(w,field);for i,x in ipairs(w.rows)do if x==r then E.ui.scroll=math.max(1,i-2);E.ui.row=i end end
  E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/explosion-'..lang..'-'..field..'.bmp')
 end
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(E.ui.last_visible==#w.rows)
end
gdi.DeleteDC(S.dc);assert(#H.diff()==0)
print('PASS: old decrypted/INI fields covered; all current ExplosionInfo members; exact scalar/array uint64; i8/u8 byte widths; packed flags and canonical presets; bounded arrays; typed reference navigation; own-only reset; authenticated build/readback; bilingual render/scroll; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@explosion-components-integration"))()'))()
