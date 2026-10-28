-- Real current StratagemInfo data, isolated profile/memory, no game installation.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,T_STRATAGEM=T_STRATAGEM,',1)
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
local C=E.MOD.stratagem;local schema=C.schema
assert(schema.check_layout(model.schemas))
local meta=model.schemas[schema.TYPE];local old=meta.size;meta.size=392
assert(not schema.check_layout(model.schemas));meta.size=old
for _,text in ipairs({'0','4294967295','4294967296','9007199254740993','1605323339894850998','18446744073709551615'})do
 local lo,hi=schema.parse_u64(text);assert(lo);assert(schema.u64_text(lo,hi)==text,text)
end
assert(not schema.parse_u64('18446744073709551616'))
assert(not schema.parse_u64('-1')and not schema.parse_u64('1e3'))
local function row(w,name)
 for _,r in ipairs(w.rows)do if r.tip_of and r.tip_of()[1]==name then return r end end
 error(w.name..' missing '..name)
end
local function index(w,name)local wanted=row(w,name);for n,r in ipairs(w.rows)do if r==wanted then return n end end end
local wanted={};local expected_count=0
for _,file in pairs(H.files)do for _,header in ipairs(G.headers(file.p,file.n))do if header.type==E.T_STRATAGEM then
 local p=file.p+header.at+24;local count=tonumber(ffi.cast('uint32_t *',p+8)[0])
 for i=0,count-1 do local id=tonumber(ffi.cast('uint32_t *',p+16+i*400)[0]);if not wanted[id]then wanted[id]=true;expected_count=expected_count+1 end end
end end end
local pages=C.all();assert(#pages==expected_count and #pages>=150,'expected every current record: '..#pages..'/'..expected_count)
local required={'StratagemTypeID','Name','Button1','Button2','Button3','Button4','Button5','Button6','Button7','Button8','Button9',
 'Category','Uses','SpawnTime','SpawnRadius','BeaconingTime','ExtraTravelTime','Cooldown','CooldownIfFail','OriginType','CallInType',
 'ObjectiveRequirement','StratagemFlags','CooldownType','PayloadSpawnPosition','Payload1','Payload2','Package','Icon','HUDType',
 'Cost','IsEnabled','DependsOnStratagemID','AdditionalStratagemID','MaxInLoadout','BeaconColor','ShipLaserPointer','AltCooldown','ExtraHellpods'}
for _,w in ipairs(pages)do
 for _,name in ipairs(required)do
  local r=row(w,name)
  if r.readonly_text then
   local value=type(r.readonly_text)=='function'and r.readonly_text()or r.readonly_text
   assert(type(value)=='string',w.name..' '..name)
  else assert(E.row_value(r)~=nil,w.name..' unreadable '..name)end
 end
 local _,n=C.array(w.def,152,8)
 assert(row(w,'PayloadSpawnPosition').readonly_text()==tostring(n),'legacy alias must equal the actual payload count')
 local arrows=E.MOD.code.native(w.def)or{}
 for i=1,9 do assert(E.row_value(row(w,'Button'..i))==(arrows[i]or 0),'button read beyond its array')end
end
print('Verified records / minimum reference fields:',#pages,#required)
local translated=pages[1]
for _,r in ipairs(translated.rows)do
 local field=r.tip_of()[1];local names=schema.names(field)
 assert(names[1]and names[2]and names[3],field..' missing translation')
 E.settings.lang='en';assert(r.label_of()==names[1])
 E.settings.lang='zh-Hans';assert(r.label_of()==names[2])
 E.settings.lang='zh-Hant';assert(r.label_of()==names[3])
 assert(r.tip_of()[2]:find(names[1],1,true),'English field name missing from localized tip')
end
E.settings.lang='en'
local orbital,eagle
for _,w in ipairs(E.weapons)do if w.stratagem and w.stratagem.def then
 if w.stratagem.family=='orbital'then orbital=orbital or w end
 if w.stratagem.family=='eagle'then eagle=eagle or w end
end end
assert(orbital and eagle)
for _,w in ipairs({orbital,eagle})do
 for _,name in ipairs(required)do row(w,name)end
 for _,r in ipairs(w.rows)do assert(r.section~='Stratagem'and r.section~='Stratagem id','old group was not replaced')end
end
local raw=assert(C.page(tonumber(ffi.cast('uint32_t *',orbital.stratagem.def.at)[0])))
assert(E.MOD.records.find(raw.hash)==raw and E.MOD.nav.tab_of(raw)=='RecStratagem')
assert(row(raw,'Cooldown').parts[1].field==row(orbital,'Cooldown').parts[1].field)
local uses=row(orbital,'Uses');assert(E.row_value(uses)==-1,'unlimited sentinel must read as -1')
local def=orbital.stratagem.def
local function record_bytes()return ffi.string(ffi.cast('const void *',def.at),400)end
local before=record_bytes()
for _,spec in ipairs(schema.FIELDS)do
 local name,off=spec[1],spec[2];local r=row(orbital,name)
 if name~='AdditionalStratagemID'and name~='DependsOnStratagemID'then
  local old=E.row_value(r)
  local value=r.storage=='flag'and(1-old)or name=='Uses'and 12 or old==0 and 1 or 0
  E.ui.weapon=orbital;E.change(r,0,false,value)
  assert(math.abs(E.row_value(r)-value)<1e-4,name..' edit failed')
  local length=spec[3]=='u16'and 2 or spec[3]:match('^bit')and 1 or 4
  local now=record_bytes()
  assert(now:sub(1,off)==before:sub(1,off),name..' touched preceding bytes')
  assert(now:sub(off+length+1)==before:sub(off+length+1),name..' touched following bytes')
  E.reset_row(orbital,r);assert(record_bytes()==before,name..' reset failed')
 end
end
local mission=row(orbital,'MissionSpecific');local selectable=row(orbital,'Selectable')
local saved_select=E.row_value(selectable);local saved_mission=E.row_value(mission)
E.ui.weapon=orbital;E.change(mission,0,false,1-saved_mission)
assert(E.row_value(selectable)==saved_select,'one bit edit changed its neighbor')
E.reset_row(orbital,mission);assert(record_bytes()==before)
local hash,hindex=row(orbital,'Icon'),index(orbital,'Icon');local original_hash=C.hash_text(hash)
E.select_weapon(orbital);E.click('value:'..hindex)
assert(E.ui.value.text==original_hash,'hash input started with a rounded number')
E.ui.value.text='18446744073709551615';assert(state.commit_value())
assert(C.hash_text(hash)=='18446744073709551615')
assert(C.hash_text(row(raw,'Icon'))=='18446744073709551615')
local now=record_bytes();assert(now:sub(1,176)==before:sub(1,176)and now:sub(185)==before:sub(185))
TEST_PRESETS_HELPER.save(E,orbital,1);assert(E.save_config())
local cfg=read(I.home..'/config.txt');assert(cfg:find('strat_Icon_lo 4294967295',1,true)and cfg:find('strat_Icon_hi 4294967295',1,true))
E.reset_row(orbital,hash);assert(C.hash_text(hash)==original_hash)
TEST_PRESETS_HELPER.load(E,orbital,1);assert(C.hash_text(hash)=='18446744073709551615')
E.reset_weapon(orbital);assert(record_bytes()==before)
-- Hash words that resemble floats must remain exact through authenticated build/seal/read-back.
assert(C.set_hash(orbital,hash,'4593671620989558785')) -- low/high words resemble finite floats
local edited_hash=C.hash_text(hash)
local staged=H.diff();assert(#staged==1 and staged[1].name=='generated_stratagem_settings.dl_bin')
assert(#staged[1].floats==0,'uint64 bits were misclassified as a float salt')
local sealed,why=H.build(staged[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==staged[1].hash)
local verified=false
for _,h in ipairs(G.headers(plain,n))do if h.type==E.T_STRATAGEM then
 local p=plain+h.at+24;local count=tonumber(ffi.cast('uint32_t *',p+8)[0])
 for i=0,count-1 do local r=p+16+i*400
  if tonumber(ffi.cast('uint32_t *',r)[0])==raw.id then
   local lo=tonumber(ffi.cast('uint32_t *',r+176)[0]);local hi=tonumber(ffi.cast('uint32_t *',r+180)[0])
   assert(schema.u64_text(lo,hi)==edited_hash,'hash correction changed the resource reference');verified=true
  end
 end
end end
assert(verified);G.free(plain);E.reset_row(orbital,hash);assert(#H.diff()==0)
E.select_weapon(orbital);E.click('value:'..hindex);E.ui.value.text='18446744073709551616'
assert(not state.commit_value()and E.ui.value,'overflow must preserve the invalid input');E.ui.value=nil
E.select_weapon(orbital)
for i=1,9 do assert(C.set_button(orbital,row(orbital,'Button'..i),4))end
local expected={4,4,4,4,4,4,4,4,4}
for i=1,9 do assert(E.row_value(row(raw,'Button'..i))==4)end
assert(E.row_value(orbital.by_id.code.row)==E.MOD.code.number(expected))
local staged={};assert(H.codes(staged,{[raw.id]=expected}))
assert(#staged==1,'code-only edits must stage the stratagem file')
local found=false
for _,header in ipairs(G.headers(staged[1].plain,staged[1].n))do if header.type==E.T_STRATAGEM then
 local P=header.at+24;local n=tonumber(ffi.cast('uint32_t *',staged[1].plain+P+8)[0])
 for k=0,n-1 do local R=P+16+k*400
  if tonumber(ffi.cast('uint32_t *',staged[1].plain+R)[0])==raw.id then
   local at=tonumber(ffi.cast('uint64_t *',staged[1].plain+R+64)[0])
   assert(tonumber(ffi.cast('uint32_t *',staged[1].plain+R+72)[0])==9)
   for i=0,8 do assert(tonumber(ffi.cast('uint32_t *',staged[1].plain+P+at+i*4)[0])==4)end
   found=true
  end
 end
end end
assert(found);for _,c in ipairs(staged)do G.free(c.plain)end
E.reset_row(orbital,orbital.by_id.code.row)
-- Definitions with no native arrows can also receive a properly allocated first code.
local empty
for _,w in ipairs(pages)do local _,count=C.array(w.def,64,4);if count==0 then empty=w;break end end
if empty then
 assert(C.set_button(empty,row(empty,'Button1'),4))
 local grown={};assert(H.codes(grown,{[empty.id]={4}}));assert(#grown==1)
 local found=false
 for _,h in ipairs(G.headers(grown[1].plain,grown[1].n))do if h.type==E.T_STRATAGEM then
  local p=grown[1].plain+h.at+24;local count=tonumber(ffi.cast('uint32_t *',p+8)[0])
  for i=0,count-1 do local r=p+16+i*400;if tonumber(ffi.cast('uint32_t *',r)[0])==empty.id then
   local at=tonumber(ffi.cast('uint64_t *',r+64)[0]);assert(tonumber(ffi.cast('uint32_t *',r+72)[0])==1)
   assert(tonumber(ffi.cast('uint32_t *',p+at)[0])==4);found=true
  end end
 end end
 assert(found);for _,c in ipairs(grown)do G.free(c.plain)end
 E.reset_row(empty,empty.by_id.code.row)
end
for i=1,9 do assert(E.row_value(row(raw,'Button'..i))==E.row_value(row(orbital,'Button'..i)))end
assert(#H.diff()==0,'all reset edits must restore original file bytes')
state.nav_open('gamedata',7);E.select_weapon(raw);E.MOD.nav.sync()
assert(E.ui.tab=='RecStratagem'and E.ui.nav.page=='gamedata')
assert(E.MOD.references.open({reference_type='stratagem_id',reference_value=function()return raw.id end}))
assert(E.ui.weapon==raw)
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info)
info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
for _,pair in ipairs({{'orbital',orbital},{'eagle',eagle},{'raw',raw}})do
 E.select_weapon(pair[2]);E.MOD.nav.sync();E.ui.message=nil
 E.tick();S.sleep(1700);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/stratagem-'..pair[1]..'-top.bmp')
 local i=index(pair[2],'PayloadSpawnPosition');E.ui.scroll=i-2;E.ui.row=i;E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/stratagem-'..pair[1]..'-payload.bmp')
end
gdi.DeleteDC(S.dc)
assert(#H.diff()==0)
print('PASS: current 400-byte / 67-member schema; all INI fields on every current record and all 3 surfaces; signed sentinels; 16-bit flags/packed bools; exact uint64/config/presets; bounded arrays; code builder; canonical fields, raw ID navigation and GDI rendering; no game writes')
]==]
assert(loadstring(start..checks,'@stratagem-components-integration'))()
