-- Real current ArcInfo records; old decrypted JSON/INI are field-name references only.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close()
local pre=assert(source:match('^(.-)local checks='))
pre=pre.."\nstart=start:gsub('MOD=MOD,','MOD=MOD,parse_rows=parse_rows,',1)\n"
local checks=[==[
local C=E.MOD.arc.schema;assert(C.check_layout(model.schemas));assert(not C.check_layout({}))
local native=model.schemas[model.schemas[E.TYPES.arc].members[1].type]
assert(native.size==104 and #native.members==21)
local old=native.size;native.size=112;assert(not C.check_layout(model.schemas));native.size=old
local old=native.members[19].count;native.members[19].count=257;assert(not C.check_layout(model.schemas));native.members[19].count=old
local function find(w,name)
 for _,r in ipairs(w.rows)do if r.tip_of and r.tip_of()[1]==name then return r end end
 error(w.name..' missing '..name)
end
local known={};for _,s in ipairs(C.FIELDS)do known[s[1]]=true end
local reference=os.getenv('SHODAN_ARC_LEGACY_FIELDS')
if reference then
 local f=assert(io.open(reference,'rb'));local count=0
 for name in f:lines()do name=name:gsub('\r$','');if name~=''then assert(known[name],'old field missing: '..name);count=count+1 end end
 f:close();assert(count==18);print('Old decrypted fields covered:',count)
end
local count=0;for _,name in pairs(C.LEGACY)do assert(known[name]);count=count+1 end;assert(count==12)
local ids=E.MOD.records.ids(E.TYPES.arc);assert(#ids>=11)
local output={}
for _,id in ipairs(ids)do
 local w=E.MOD.records.page(E.TYPES.arc,id);assert(#w.rows==21)
 for _,s in ipairs(C.FIELDS)do
  local r=find(w,s[1]);assert(r.component=='ArcType')
  local v=r.hash64 and E.MOD.stratagem.hash_text(r)or E.row_value(r);assert(v~=nil,w.name..' unreadable '..s[1])
  output[#output+1]=id..'\t'..s[1]..'\t'..tostring(v)
  for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')end
  for _,p in ipairs(r.parts)do assert(p.field.kind==E.TYPES.arc,'referenced component expanded inline')end
 end
end
write(TEST_WORK..'/current-arc-values.tsv',table.concat(output,'\n'))
print('Current arc records / fields per record:',#ids,#C.FIELDS)
local w=E.MOD.records.page(E.TYPES.arc,ids[1]);E.ui.weapon=w
local at=E.tables[E.TYPES.arc].index[w.id];local base=E.tables[E.TYPES.arc].copies[1]+24+at
local function bytes()return ffi.string(ffi.cast('const void *',base),C.SIZE)end
local original=bytes()
for _,s in ipairs(C.FIELDS)do if s[3]~='id'and s[3]~='u64'and not s[8]then
 local r=find(w,s[1]);local value=E.row_value(r);local target=r.storage=='flag'and(1-value)or value==0 and 1 or 0
 local size=s[3]:match('^bit')and 1 or 4
 E.change(r,0,false,target);assert(E.row_value(r)==target,s[1]..' edit failed')
 local now=bytes();assert(now:sub(1,s[2])==original:sub(1,s[2])and now:sub(s[2]+size+1)==original:sub(s[2]+size+1),s[1]..' changed neighboring bytes')
 E.reset_row(w,r);assert(bytes()==original)
end end
for _,name in ipairs({'max_chain_length','max_chain_split','demolition_strength','unk_uint32_0x0060'})do
 local r=find(w,name);E.change(r,0,false,4294967295);assert(E.row_value(r)==4294967295);E.reset_row(w,r)
end
for _,s in ipairs(C.FIELDS)do if s[3]=='u64'then
 local r=find(w,s[1]);assert(E.MOD.stratagem.set_hash(w,r,'18446744073709551615'))
 assert(E.MOD.stratagem.hash_text(r)=='18446744073709551615');E.reset_row(w,r);assert(bytes()==original)
end end
local resource=find(w,'explosion_effect_path')
assert(not E.MOD.stratagem.set_hash(w,resource,'18446744073709551616'))
assert(E.MOD.stratagem.set_hash(w,resource,'4593671620989558785'))
E.change(find(w,'hit_audio_event'),0,false,1069547521)
E.change(find(w,'unk_uint32_0x0060'),0,false,1069547521)
local expected=bytes();local staged=H.diff();assert(#staged==1 and staged[1].name=='generated_arc_settings.dl_bin'and #staged[1].floats==0)
local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
local verified
for _,h in ipairs(G.headers(plain,n))do if h.type==E.TYPES.arc then
 local P=plain+h.at+24;local count=tonumber(ffi.cast('uint32_t *',P+8)[0])
 for i=0,count-1 do local row=P+16+i*C.SIZE
  if tonumber(ffi.cast('uint32_t *',row)[0])==w.id then assert(ffi.string(row,C.SIZE)==expected);verified=true end
 end
 local index,entries=E.parse_rows(ffi.string(P,h.size),C.SIZE,{tail=true})
 assert(index and entries==#ids and index[w.id]==at)
 assert(h.size>16+count*C.SIZE and not E.parse_rows(ffi.string(P,h.size),C.SIZE,{}),'grown-table parser not exercised')
end end
assert(verified);G.free(plain)
E.presets.save_weapon_preset(w,1);assert(E.save_config())
assert(read(I.home..'/config.txt'):find('explosion_effect_path_lo ',1,true))
E.reset_weapon(w);assert(bytes()==original)
E.presets.load_weapon_preset(w,1);assert(bytes()==expected);E.reset_weapon(w);assert(bytes()==original)
assert(E.MOD.references.type_of(find(w,'type'))=='arc_id')
assert(not E.MOD.references.type_of(find(w,'explosion_effect_path')))
assert(not E.MOD.references.type_of(find(w,'hit_effect_damage_type')))
local reference=find(w,'damage_info_type');local id=E.MOD.records.ids(E.T_DAMAGE)[1]
E.ui.weapon=w;E.change(reference,0,false,id);assert(E.row_value(reference)==id)
E.change(reference,0,false,4294967295);assert(E.row_value(reference)==id)
E.select_weapon(w);local i;for n,r in ipairs(w.rows)do if r==reference then i=n end end
local writes=state.writes;E.click('value:'..i);E.click('value:'..i)
assert(state.writes==writes and E.ui.tab=='RecDamage'and E.ui.weapon.id==id)
local related=E.ui.weapon;local damage=related.by_id.damage.row;local old=E.row_value(damage)
E.change(damage,0,false,old+1);E.reset_weapon(w)
assert(E.row_value(damage)==old+1,'arc reset followed damage reference');E.reset_row(related,damage)
assert(bytes()==original and #H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.click('set:lang:'..lang);S.lang=function()return E.settings.lang end
 E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil;E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/arc-'..lang..'-top.bmp')
 local r=find(w,'explosion_effect_path');for i,x in ipairs(w.rows)do if x==r then E.ui.scroll=math.max(1,i-2);E.ui.row=i end end
 E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/arc-'..lang..'-effects.bmp')
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(E.ui.last_visible==#w.rows)
end
gdi.DeleteDC(S.dc);assert(#H.diff()==0)
print('PASS: old 18 decrypted / 12 INI fields and all 21 current ArcInfo members; exact resource hashes; uint32 limits; byte boundaries; typed damage link; own-only reset; config/presets; authenticated build/readback and correction trailer; bilingual GDI/scroll; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@arc-components-integration"))()'))()
