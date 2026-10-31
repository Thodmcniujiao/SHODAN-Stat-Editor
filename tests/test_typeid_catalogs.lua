-- Component record indices and TypeID parameter groups; isolated profile/memory and no game writes.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,T_STRATAGEM=T_STRATAGEM,',1)
start=start:gsub('assert%(#H.load%(TEST_GAME,original%)==0%)',[[
for _,name in ipairs({'generated_projectile_settings.dl_bin','generated_stratagem_settings.dl_bin','generated_damage_settings.dl_bin','generated_explosion_settings.dl_bin','generated_status_effect_settings.dl_bin','generated_arc_settings.dl_bin','generated_beam_settings.dl_bin'})do original[name]=read(TEST_GAME..'/'..name)end
assert(#H.load(TEST_GAME,original)==0)
]],1)
local checks=[==[
local R=E.MOD.record_names
local orbital,eagle=E.weapons_in('Orbital'),E.weapons_in('Eagle')
local function all_rows(page)
 local rows={}
 for _,g in ipairs(page.component_groups or{{rows=page.rows}})do for _,r in ipairs(g.rows)do rows[#rows+1]=r end end
 return rows
end
for _,spec in ipairs({{'Orbital',0xCDBC43D8,'bombardment'},{'Eagle',0x556FF68B,'eagle'}})do
 local tab,kind,typ=unpack(spec);local t=E.tables[kind];local layout=t.records_layout
 local list=E.weapons_in(tab);assert(#list==layout.record_count and list[1].component_index==0)
 local bucket_count=layout.data_offset/16;local mapped={};local keys=0
 for bucket=0,bucket_count-1 do
  local ptr=ffi.cast('uint8_t *',t.copies[1]+24+bucket*16)
  if ffi.cast('uint64_t *',ptr)[0]~=0 then
   local index=tonumber(ffi.cast('uint32_t *',ptr+8)[0]);mapped[index]=true;keys=keys+1
  end
 end
 local orphan
 for i,page in ipairs(list)do
  local id=i-1;assert(page.component_index==id and page.component_offset==layout.data_offset+id*layout.stride)
  assert(R.id_of(page)==id and R.type_of(page)==typ,'wrong primary ID/type')
  assert(R.label(page):match('^#'..id..' '),'missing component index prefix')
  assert(R.jump(tab,tostring(id))==page and R.jump(tab,string.format('0x%X',id))==page,'index jump failed')
  assert(E.MOD.records.find(page.hash)==page,'component config page cannot be restored')
  assert(page.hash:sub(1,2)==(tab=='Orbital'and'F8'or'F9'))
  local row
  for _,r in ipairs(all_rows(page))do
   if r.parts[1]and r.parts[1].field.kind==kind and(r.storage=='f32'or r.storage=='u32')then row=r;break end
  end
  assert(row,'component record has no editable own fields')
  local f=row.parts[1].field;assert(f.offset>=page.component_offset and f.offset<page.component_offset+layout.stride)
  E.ui.weapon=page;local old=E.row_value(row);local target=old==0 and 1 or 0
  E.change(row,0,false,target);assert(E.row_value(row)==target,'component index edit failed')
  assert(E.modified(page),'shared canonical owner modification not shown')
  E.reset_weapon(page);assert(E.row_value(row)==old,'component reset failed')
  if not mapped[id]then orphan=orphan or{page=page,row=row,value=old}end
 end
 assert(orphan,'fixture should include unindexed records, to catch hash-based enumeration')
 local page,row=orphan.page,orphan.row
 E.ui.weapon=page;E.change(row,0,false,orphan.value==0 and 1 or 0)
 TEST_PRESETS_HELPER.save(E,page,1);assert(E.save_config());E.reset_weapon(page)
 TEST_PRESETS_HELPER.load(E,page,1);assert(E.row_value(row)==(orphan.value==0 and 1 or 0));E.reset_weapon(page)
 assert(not R.jump(tab,tostring(layout.record_count)),'out-of-range index accepted')
 print(tab..' complete component records / mapped hashes:',#list,keys)
end
local beam=E.weapons_in('OrbitalBeam');assert(#beam==2,'orbital weapon view must stay unchanged')
for _,w in ipairs(beam)do assert(w.orbital_beam and R.id_of(w)==w.hash)end
local barrage
for _,page in ipairs(orbital)do if page.name:find('120mm',1,true)then barrage=page end end
assert(barrage and barrage.component_index==19,'wrong current bombardment record for 120mm')
assert(R.jump('Orbital','19')==barrage and not R.jump('Orbital','139'),'StratagemTypeID still used for lookup')
-- Related StratagemInfo values still write through their original canonical owner.
local cooldown=assert(barrage.by_id.cooldown);local before=E.row_value(cooldown.row)
E.ui.weapon=barrage;E.change(cooldown.row,0,false,before+1);assert(E.row_value(cooldown.row)==before+1)
assert(E.save_config());E.reset_row(barrage,cooldown.row);assert(E.row_value(cooldown.row)==before)
-- A projectile reference on the cloned index page navigates through the real click handler.
E.select_weapon(barrage)
for _,g in ipairs(barrage.component_groups)do E.ui.expanded_components[barrage.hash..':'..g.type]=true end
barrage.sync_rows()
local shot=barrage.by_id.barrage_projectile1;local position
for i,row in ipairs(barrage.rows)do if row.parts==shot.row.parts then position=i;break end end
assert(position and E.MOD.references.type_of(shot.row)=='projectile_id')
E.click('value:'..position);E.click('value:'..position)
assert(E.ui.tab=='RecProjectile'and E.ui.weapon.id==E.row_value(shot.row),'index page reference navigation failed')
-- TypeID names stay local to their numeric table; entity hashes do not override them.
R.ensure();R.by.bombardment=R.by.bombardment or{}
R.by.bombardment['19']=nil -- exercise fallback even when the portable pack already names this index
local key=barrage.component_keys[1];local hex=string.format('%08X%08X',tonumber(ffi.cast('const uint32_t *',key)[1]),tonumber(ffi.cast('const uint32_t *',key)[0]))
R.by.bombardment[hex]='Legacy component name';assert(R.name_of(barrage)~='Legacy component name')
R.by.bombardment['19']='Component index custom name';assert(R.name_of(barrage)=='Component index custom name')
E.ui.tab='Orbital';E.ui.search.text='Component index custom name'
local results=E.weapons_in('?search');assert(#results==1 and results[1]==barrage);E.ui.search.text=''
R.by.bombardment['19']=nil;R.by.bombardment[hex]=nil
-- Two hashes pointing to one row must not duplicate it; hashless rows must remain visible.
local fake=require('component_records').new({weapons={},by_hash={},wrap=function(page,groups)page.component_groups=groups end})
local list=fake:build({tab='fake',kind=42,type='fake',prefix='FA',component='Fake',label={'Fake','Fake','Fake'},sub={'Fake','Fake','Fake'},
 table={index={A=36,B=36},records_layout={data_offset=32,stride=4,record_count=3}},make_rows=function(page)page.rows={}end})
assert(#list==3 and #list[2].component_keys==2 and #list[1].component_keys==0 and #list[3].component_keys==0)
local kinds={
 [0xE0A72CF0]='damage',[0xBD4042C2]='projectile',[0x2AEA2592]='explosion',
 [0xAFDF0267]='arc',[0xC5085606]='beam',[0xC63E0B22]='status',
}
local count,samples={},{}
for _,page in ipairs(E.MOD.records.all())do
 local name=kinds[page.kind]
 if name then
  count[name]=(count[name]or 0)+1;samples[name]=samples[name]or page
  local schema=require(name..'_components');local rank={}
  for i,g in ipairs(schema.GROUP_ORDER)do rank[g]=i;assert(schema.GROUPS[g])end
  local last=0;local seen={};local section
  for _,row in ipairs(page.rows)do
   assert(row.section_level=='group',name..' missing group styling: '..row.id)
   local group=assert(row.section:match('([^:]+)$'));local at=assert(rank[group],name..' unknown group '..group)
   assert(at>=last,name..' unordered group: '..group);last=at
   if row.section~=section then assert(not seen[row.section],name..' repeated group');seen[row.section]=true;section=row.section end
   assert(row.section_of and type(row.section_of())=='string')
  end
 end
end
local changes={damage='Damage',projectile='calibre',explosion='outer_radius',arc='speed',beam='radius',status='duration'}
for name,field in pairs(changes)do
 local page=samples[name];local row
 for _,r in ipairs(page.rows)do if r.tip_of and r.tip_of()[1]==field then row=r;break end end
 assert(row,name..' editable field missing');local value=E.row_value(row);local next_value=value==0 and 1 or 0
 E.ui.weapon=page;E.change(row,0,false,next_value)
 assert(E.row_value(row)==next_value,name..' edit failed after grouping')
 E.reset_row(page,row);assert(E.row_value(row)==value,name..' reset failed')
 assert(count[name]>0);print(name..' fully grouped enum rows:',count[name])
end
assert(#H.diff()==0,'reset must restore original game bytes')
local function render(w,name)
 E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end;S.w,S.h=1272,1296
 E.select_weapon(w);E.MOD.nav.sync();E.ui.message=nil
 if w.component_groups then E.ui.expanded_components[w.hash..':StratagemType']=true;w.sync_rows()end
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
 local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
 local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 E.ui.version=E.ui.version+1;E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..name..'.bmp')
 gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib)
end
render(barrage,'orbital-indices');render(eagle[2],'eagle-indices');render(samples.damage,'damage-groups');render(samples.projectile,'projectile-groups')
print('PASS: complete zero-based component records, hashless/shared rows, index jump/search/names, canonical edits and presets, unchanged orbital weapon page, all six TypeID groups and write/reset')

]==]
assert(loadstring(start..checks,"@typeid-catalogs"))()
