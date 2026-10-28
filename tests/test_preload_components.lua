-- Real editor, current local tables, isolated profile; never writes to the game folder.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs(I.list_files(TEST_GAME,'generated_*.dl_bin'))do
 if not original[name]then original[name]=read(TEST_GAME..'/'..name)end
end
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local C=E.MOD.preload
local slots={'PreloadGlobal','PreloadLoadout','PreloadEnemy','PreloadWorld','PreloadCatalog','PreloadHotjoin'}
local misc=E.MOD.nav.page('misc');assert(table.concat(misc.subs[4].tabs,',')=='PreloadExtra,'..table.concat(slots,','))
local entity_count,editable=0,0
for _,slot in ipairs(slots)do
 local list=E.weapons_in(slot);assert(#list>0,slot..' empty');print(slot,#list)
 for _,p in ipairs(list)do
  assert(E.by_hash[p.hash]==p)
  if p.entity_hash then entity_count=entity_count+1 end
  for _,r in ipairs(p.rows)do if not r.empty then editable=editable+1 end end
 end
end
assert(entity_count==710,entity_count)
assert(#E.weapons_in('PreloadCatalog')==3632)
assert(#E.weapons_in('PreloadEnemy')==160)
assert(#E.weapons_in('PreloadWorld')==625,'distinct same-name DL blocks were merged')
assert(#E.weapons_in('PreloadLoadout')==984)
assert(#E.weapons_in('PreloadGlobal')==12,#E.weapons_in('PreloadGlobal'))
assert(C.hash_input('packages/content/global_resources')==C.hash_input('0x18235E0C9EC0E636'))
assert(C.hash_input('0xFFFFFFFFFFFFFFFF')=='18446744073709551615')
local refs={}
-- Exercise every editable hash and integer field, including high bits that resemble f32.
for _,slot in ipairs({'PreloadLoadout','PreloadEnemy','PreloadWorld'})do
 for _,p in ipairs(E.weapons_in(slot))do
  E.ui.weapon=p
  for _,r in ipairs(p.rows)do if not r.empty then
   assert(r.storage~='u64'or(r.hash64 and #r.parts==2))
   for _,part in ipairs(r.parts)do
    local key=part.field.key
    if not refs[key]then
     refs[key]=true
     local field=part.field;local t=E.tables[field.kind];local at=t.copies[1]+24+field.offset
     local width=(field.storage=='flag'or field.storage=='u8')and 1 or 4
     local before=ffi.string(ffi.cast('const void *',at-4),width+8)
     local hash_at=r.hash64 and E.tables[r.parts[1].field.kind].copies[1]+24+r.parts[1].field.offset
     local hash_before=hash_at and ffi.string(ffi.cast('const void *',hash_at-4),16)
     local old=r.hash64 and E.MOD.stratagem.hash_text(r)or E.row_value(r)
     local previous=field.storage=='flag'and tonumber(ffi.cast('uint8_t *',at)[0])or
      width==1 and tonumber(ffi.cast('uint8_t *',at)[0])or tonumber(ffi.cast('uint32_t *',at)[0])
     -- Real editor controls apply whole uint64 values without passing through a Lua number.
     local value=r.storage=='u64'and'0xDEADBEEF3F800001'or field.storage=='flag'and 1-previous or width==1 and 173 or 1065353217
     if r.hash64 then assert(E.MOD.stratagem.set_hash(p,r,value))else E.change(r,0,false,value)end
     local now=ffi.string(ffi.cast('const void *',at-4),width+8)
     if r.storage~='u64'then
      assert(now:sub(1,4)==before:sub(1,4)and now:sub(width+5)==before:sub(width+5),'integer touched neighbors')
     end
     if #r.parts>1 then
      assert(E.MOD.stratagem.hash_text(r)=='16045690982162759681',tostring(E.MOD.stratagem.hash_text(r)))
      local hash_now=ffi.string(ffi.cast('const void *',hash_at-4),16)
      assert(hash_now:sub(1,4)==hash_before:sub(1,4)and hash_now:sub(13)==hash_before:sub(13),'uint64 touched neighboring bytes')
     end
     E.reset_row(p,r);assert((r.hash64 and E.MOD.stratagem.hash_text(r)or E.row_value(r))==old,r.id..' reset failed')
    end
   end
  end end
 end
end
assert(#H.diff()==0)
-- One representative of each independently built source file, with authenticated readback.
local tested={}
for _,slot in ipairs({'PreloadLoadout','PreloadEnemy','PreloadWorld'})do
 for _,p in ipairs(E.weapons_in(slot))do
  local row
  for _,r in ipairs(p.rows)do if r.hash64 then row=r;break end end
  if row then
   local t=E.tables[row.parts[1].field.kind]
   local file
   for name,f in pairs(H.files)do
    local base=tonumber(ffi.cast('uintptr_t',f.p))
    if t.copies[1]>=base and t.copies[1]<base+f.n then file=name;break end
   end
   if file and not tested[file]then
    E.ui.weapon=p;assert(E.MOD.stratagem.set_hash(p,row,'0xDEADBEEF3F800001'))
    local diff=H.diff();assert(#diff==1 and diff[1].name==file)
    assert(#diff[1].floats==0,file..' package hash treated as floating checksum salt')
    if file=='generated_entities.dl_bin'then diff[1].demolition_schemas=model.schemas end
    print('building',file)
    local cipher,why=H.build(diff[1]);assert(cipher,file..': '..tostring(why))
    local plain,n=G.open_sealed(cipher);assert(plain and G.murmur64(plain,n)==diff[1].hash)
    local field=row.parts[1].field;local base=tonumber(ffi.cast('uintptr_t',H.files[file].p))
    local off=t.copies[1]+24+field.offset-base
    assert(tonumber(ffi.cast('uint32_t *',plain+off)[0])==0x3F800001)
    assert(tonumber(ffi.cast('uint32_t *',plain+off+4)[0])==0xDEADBEEF)
    G.free(plain)
    assert(E.save_config());TEST_PRESETS_HELPER.save(E,p,1);E.reset_weapon(p)
    TEST_PRESETS_HELPER.load(E,p,1);assert(E.MOD.stratagem.hash_text(row)=='16045690982162759681')
    E.reset_weapon(p);tested[file]=true
   end
  end
 end
end
assert(#H.diff()==0)
local files=0;for name in pairs(tested)do files=files+1;print('authenticated build',name)end
assert(files>=8,files)
-- Empty array contents remain visible, and a game layout change disables the parser.
local env=0x68E17506
assert(C.check_layout(env,model.schemas)and not C.check_layout(env,{}))
local size=model.schemas[env].size;model.schemas[env].size=size+8
assert(not C.check_layout(env,model.schemas));model.schemas[env].size=size
local empty=false
for _,p in ipairs(E.weapons_in('PreloadWorld'))do for _,r in ipairs(p.rows)do
 if r.id:find('count_',1,true)and r.readonly_text=='0'then empty=true end
end end
assert(empty)
-- Real text-entry commit accepts a catalog path without loss of any uint64 bits.
local p=E.weapons_in('PreloadEnemy')[1];E.ui.weapon=p
for i,r in ipairs(p.rows)do if r.hash64 then
 E.ui.value={weapon=p,n=i,text='packages/content/global_resources'}
 assert(state.commit_value());assert(E.MOD.stratagem.hash_text(r)==C.hash_input('0x18235E0C9EC0E636'))
 E.reset_row(p,r);break
end end
assert(#H.diff()==0)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
for _,lang in ipairs({'zh-Hans','en'})do
 E.settings.lang=lang;S.lang=function()return E.settings.lang end
 for _,slot in ipairs(slots)do
  local nav,k=E.MOD.nav.locate(slot);assert(nav.id=='misc'and k==4)
  state.nav_open(nav.id,k);E.click('cat:'..slot)
  if slot=='PreloadLoadout'then
   for _,p in ipairs(E.weapons_in(slot))do if p.entity_hash then E.select_weapon(p);break end end
  end
  E.tick();S.sleep(1500);E.tick();assert(state.ui_errors==0)
  S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..slot..'-'..lang..'.bmp')
 end
end
state.nav_open('misc',4);E.click('cat:PreloadCatalog');E.ui.search.text='global_resources'
local found=E.weapons_in('?search');assert(#found==1 and found[1].name=='packages/content/global_resources')
E.ui.search.text=''
for _,p in ipairs(E.weapons_in('PreloadHotjoin'))do for _,r in ipairs(p.rows)do assert(r.empty and #r.parts==0)end end
gdi.DeleteDC(S.dc)
print('PASS: '..entity_count..' entity components, '..editable..' editable rows; exact uint64, all unique fields reset, '..files..' authenticated source builds, presets/config, schema gating, catalog search, bilingual rendering; no game writes')
]==]
assert(loadstring(start..checks,'@preload-components-integration'))()
