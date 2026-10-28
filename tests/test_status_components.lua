-- StatusEffectInfo: real current records, both dynamic arrays, isolated editor/profile/buffers.
local f=assert(io.open(TEST_ROOT..'/tests/test_reference_navigation.lua','rb'))
local source=f:read('*a');f:close();local pre=assert(source:match('^(.-)local checks='))
local checks=[==[
local X=E.MOD.status_component;local C=X.schema
assert(C.check_layout(model.schemas));assert(not C.check_layout({}))
local native=model.schemas[model.schemas[E.T_STATUS].members[1].type];assert(native.size==160 and #native.members==30)
local old=native.size;native.size=168;assert(not C.check_layout(model.schemas));native.size=old
local nested=model.schemas[native.members[30].type];local old=nested.size;nested.size=32;assert(not C.check_layout(model.schemas));nested.size=old
local function find(w,name)
 for _,r in ipairs(w.rows)do if r.tip_of and r.tip_of()[1]==name then return r end end
 error(w.name..' missing '..name)
end
local known={};for _,s in ipairs(C.FIELDS)do known[s[1]]=true end;for _,s in ipairs(C.BITS)do known[s[1]]=true end
local reference=os.getenv('SHODAN_STATUS_LEGACY_FIELDS')
if reference then local f=assert(io.open(reference,'rb'));local n=0
 for name in f:lines()do name=name:gsub('\r$','');assert(known[name],name..' missing');n=n+1 end
 f:close();assert(n==27);print('Old decrypted fields covered:',n)
end
local n=0;for _,name in pairs(C.LEGACY)do assert(known[name]);n=n+1 end;assert(n==5)
local ids=E.MOD.records.ids(E.T_STATUS);assert(#ids==73)
local output,arrays={},{};local total=0;local sums={0,0}
for _,id in ipairs(ids)do
 local w=E.MOD.records.page(E.T_STATUS,id);local at=E.tables[E.T_STATUS].index[id]
 assert(X.debug_name(at)~=nil and X.name(id),'debug string unavailable')
 local extra=0
 for k,a in ipairs(C.ARRAYS)do local pos,n=X.array(at,a);assert(pos and n)
  sums[k]=sums[k]+n;extra=extra+n*#a.fields
  if n>0 then arrays[k]=arrays[k]or{page=w,pos=pos,n=n}end
 end
 assert(#w.rows==#C.FIELDS+#C.BITS+extra)
 for _,s in ipairs(C.FIELDS)do local r=find(w,s[1]);assert(r.component=='StatusEffectType')
  local value=r.hash64 and E.MOD.stratagem.hash_text(r)or type(r.readonly_text)=='function'and r.readonly_text()or r.readonly_text or E.row_value(r)
  assert(value~=nil,w.name..' unreadable '..s[1]);output[#output+1]=id..'\t'..s[1]..'\t'..tostring(value)
  for _,lang in ipairs({'en','zh-Hans','zh-Hant'})do E.settings.lang=lang;assert(r.label_of()~=''and r.section_of()~=''and r.component_of()~='')end
 end
 for _,s in ipairs(C.BITS)do local v=E.row_value(find(w,s[1]));assert(v==0 or v==1);output[#output+1]=id..'\t'..s[1]..'\t'..v end
 for _,r in ipairs(w.rows)do
  for _,p in ipairs(r.parts)do assert(p.field.kind==E.T_STATUS,'referenced damage expanded')end
  if r.tip_of()[1]:find('[',1,true)then
   local value=r.hash64 and E.MOD.stratagem.hash_text(r)or E.row_value(r);assert(value~=nil)
   output[#output+1]=id..'\t'..r.tip_of()[1]..'\t'..tostring(value)
  end
 end
 total=total+#w.rows
end
write(TEST_WORK..'/current-status-values.tsv',table.concat(output,'\n'))
assert(arrays[1]and arrays[2]and sums[1]==2 and sums[2]==9)
print('Current statuses / fixed rows / modifier entries / unknown entries / displayed rows:',#ids,#C.FIELDS+#C.BITS,sums[1],sums[2],total)
local w=arrays[2].page;E.ui.weapon=w
local at=E.tables[E.T_STATUS].index[w.id];local base=E.tables[E.T_STATUS].copies[1]+24+at
local function bytes()return ffi.string(ffi.cast('const void *',base),C.SIZE)end
local original=bytes()
for _,s in ipairs(C.FIELDS)do if s[3]~='id'and s[3]~='string'and s[3]~='array'and s[3]~='u64'and not s[8]then
 local r=find(w,s[1]);local v=E.row_value(r);local target=r.storage=='flag'and(1-v)or v==0 and 1 or 0
 local size=(s[3]=='u8'or s[3]:match('^bit'))and 1 or 4
 E.change(r,0,false,target);assert(E.row_value(r)==target)
 local now=bytes();assert(now:sub(1,s[2])==original:sub(1,s[2])and now:sub(s[2]+size+1)==original:sub(s[2]+size+1),s[1]..' changed neighboring bytes')
 E.reset_row(w,r);assert(bytes()==original)
end end
local flags=find(w,'status_flags');E.change(flags,0,false,255)
for _,s in ipairs(C.BITS)do local r=find(w,s[1]);E.change(r,0,false,0);assert(E.row_value(flags)==255-2^s[3]);E.change(r,0,false,1);assert(E.row_value(flags)==255)end
E.reset_row(w,flags);assert(bytes()==original)
-- Name/counts are structural, never editable. Invalid pointers/counts are not dereferenced.
local writes=state.writes
for _,name in ipairs({'debug_name','modified_stats_multipliers','unk_array_0x0090'})do E.change(find(w,name),0,false,999);assert(state.writes==writes)end
local ptr=ffi.new('uint8_t[16]');ffi.copy(ptr,ffi.cast('const void *',base+144),16)
ffi.cast('uint32_t *',base+152)[0]=4097;assert(not X.array(at,C.ARRAYS[2]))
ffi.copy(ffi.cast('void *',base+144),ptr,16);ffi.cast('uint64_t *',base+144)[0]=1;assert(not X.array(at,C.ARRAYS[2]))
ffi.copy(ffi.cast('void *',base+144),ptr,16)
local str=ffi.new('uint8_t[8]');ffi.copy(str,ffi.cast('const void *',base+8),8)
ffi.cast('uint64_t *',base+8)[0]=1;assert(not X.debug_name(at));ffi.copy(ffi.cast('void *',base+8),str,8)
-- Dynamic fields edit only their actual storage, including signed multipliers and unknown nested data.
local file=H.files['generated_status_effect_settings.dl_bin'];local initial=ffi.string(file.p,file.n)
for k,a in ipairs(C.ARRAYS)do local page=arrays[k].page;E.ui.weapon=page
 for _,child in ipairs(a.fields)do
  local r=find(page,a.name..'[1].'..child[1]);local before=ffi.string(file.p,file.n)
  local offset=(E.tables[E.T_STATUS].copies[1]-tonumber(ffi.cast('uintptr_t',file.p)))+24+r.parts[1].field.offset
  if child[3]=='u64'then assert(E.MOD.stratagem.set_hash(page,r,'18446744073709551615'));assert(E.MOD.stratagem.hash_text(r)=='18446744073709551615')
  else E.change(r,0,false,child[3]=='f32'and -2.5 or 1);assert(E.row_value(r)==(child[3]=='f32'and -2.5 or 1))end
  local size=child[3]=='u64'and 8 or 4;local now=ffi.string(file.p,file.n)
  assert(now:sub(1,offset)==before:sub(1,offset)and now:sub(offset+size+1)==before:sub(offset+size+1))
  E.reset_row(page,r);assert(ffi.string(file.p,file.n)==before)
 end
end
-- Only actual float members of both arrays can become float correction candidates.
local float_rows={}
for k,a in ipairs(C.ARRAYS)do local page=arrays[k].page;local child=a.fields[2];local r=find(page,a.name..'[1].'..child[1])
 E.ui.weapon=page;E.change(r,0,false,E.row_value(r)+.125);float_rows[k]={page,r}
end
local staged=H.diff();assert(#staged==1 and #staged[1].floats==2,'nested float offsets not recognized')
G.free(staged[1].plain)
for _,pair in ipairs(float_rows)do E.reset_row(pair[1],pair[2])end
assert(ffi.string(file.p,file.n)==initial)
E.ui.weapon=w
for _,name in ipairs({'shading_environment','particle_effect_path'})do local r=find(w,name)
 assert(E.MOD.stratagem.set_hash(w,r,'18446744073709551615'));assert(E.MOD.stratagem.hash_text(r)=='18446744073709551615');E.reset_row(w,r)
end
local hash=find(w,'shading_environment');assert(not E.MOD.stratagem.set_hash(w,hash,'18446744073709551616'))
assert(E.MOD.stratagem.set_hash(w,hash,'4593671620989558785'))
local nested_hash=find(w,'unk_array_0x0090[1].uint64_0x08');assert(E.MOD.stratagem.set_hash(w,nested_hash,'4593671620989558785'))
E.change(find(w,'audio_event_start'),0,false,1069547521)
E.change(flags,0,false,255);E.change(find(w,'block_sprint'),0,false,0)
local expected=ffi.string(file.p,file.n);local staged=H.diff();assert(#staged==1 and #staged[1].floats==0,'uint64/ID bits classified as floats')
local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
for _,h in ipairs(G.headers(plain,n))do if h.type==E.T_STATUS then local P=h.at+24
 assert(ffi.string(plain+P,file.n-P)==expected:sub(P+1),'builder changed status data, strings or array elements')
end end
G.free(plain)
TEST_PRESETS_HELPER.save(E,w,1);assert(E.save_config())
local n=0;for _,v in ipairs(TEST_PRESETS_HELPER.values(E,w,1))do if v.id=='status_flags'then n=n+1;assert(v.value==247)end end;assert(n==1)
E.reset_weapon(w);assert(ffi.string(file.p,file.n)==initial)
TEST_PRESETS_HELPER.load(E,w,1);assert(ffi.string(file.p,file.n)==expected);E.reset_weapon(w);assert(ffi.string(file.p,file.n)==initial)
local reference=find(w,'damage_info_type');local id=E.MOD.records.ids(E.T_DAMAGE)[1]
E.ui.weapon=w;E.change(reference,0,false,id);E.change(reference,0,false,4294967295);assert(E.row_value(reference)==id)
E.select_weapon(w);local i;for n,r in ipairs(w.rows)do if r==reference then i=n end end
local writes=state.writes;E.click('value:'..i);E.click('value:'..i);assert(E.ui.tab=='RecDamage'and E.ui.weapon.id==id and state.writes==writes)
local related=E.ui.weapon;local damage=related.by_id.damage.row;local old=E.row_value(damage)
E.change(damage,0,false,old+1);E.reset_weapon(w);assert(E.row_value(damage)==old+1);E.reset_row(related,damage)
assert(#H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do E.click('set:lang:'..lang);S.lang=function()return E.settings.lang end
 for _,pair in ipairs({{'nested',w},{'modifiers',arrays[1].page}})do E.select_weapon(pair[2]);E.MOD.nav.sync();E.ui.message=nil
  E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/status-'..lang..'-'..pair[1]..'-top.bmp')
  local r=find(pair[2],pair[1]=='nested'and'unk_array_0x0090'or'modified_stats_multipliers')
  for i,x in ipairs(pair[2].rows)do if x==r then E.ui.scroll=math.max(1,i-2);E.ui.row=i end end
  E.tick();assert(state.ui_errors==0);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/status-'..lang..'-'..pair[1]..'-array.bmp')
  E.ui.scroll=E.ui.last_page or 1;E.ui.row=#pair[2].rows;E.tick();assert(E.ui.last_visible==#pair[2].rows)
 end
end
gdi.DeleteDC(S.dc);assert(#H.diff()==0)
print('PASS: all current status records and old 27/5 reference fields; strings and both bounded arrays; nested writes/floats/uint64; shared packed flags; exact build/readback; config/presets; typed jump/reset isolation; bilingual rendering/scroll; no game writes')
]==]
assert(loadstring(pre..'local checks='..string.format('%q',checks)..'\nassert(loadstring(start..checks,"@status-components-integration"))()'))()
