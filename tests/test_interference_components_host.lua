-- Production component catalog and native writer; portable profile, no game writes or Steam/proxy changes.
local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
prefix=prefix:gsub('save=save_config,','test_tables=tables,test_kinds=KINDS,read_bytes=api.read,render=draw,save=save_config,')
local checks=[==[
local phase,began=0,tonumber(ffi.C.GetTickCount64())
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'interference test timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if phase==0 and state.phase=='ready'then
   local e=assert(TEST_PARAMETERS);local A=require('interference_components')
   assert(#H.diff()==0,'startup changed game data')
   local parent,sub=assert(e.MOD.nav.locate('StratagemBlockerComponents'))
   assert(parent.id=='components'and parent.subs[sub-1].tabs[1]=='HellpodComponents')
   assert(parent.subs[sub].name[2]=='干扰'and #parent.subs[sub].tabs==2)
   local expected={jammer=5,scrambler=8};local counts={};local edited={};local sync=0
   for _,spec in ipairs(A.SPECS)do
    local view=assert(e.MOD.weapon_component_views[spec.KEY]);assert(view.full,view.why)
    assert(#view.pages>0 and #spec.FIELDS==expected[spec.KEY])
    local indices={};local table_=assert(e.test_tables[spec.HASH])
    for _,page in ipairs(view.pages)do
     page.ensure_rows();assert(#page.rows==expected[spec.KEY],page.name..': field lost')
     local seen={};local unknown=false
     for _,row in ipairs(page.rows)do
      assert(row.component==spec.TYPE and row.parts[1].field.kind==spec.HASH,'other entity/component leaked')
      local group=row.section:match(':(.+)$')
      if group=='unknown'then unknown=true else assert(not unknown,'known and unknown fields mixed')end
      for _,part in ipairs(row.parts)do
       assert(not seen[part.field.offset]);seen[part.field.offset]=true
       assert(part.field.offset>=page.component_offset and part.field.offset<page.component_offset+spec.SIZE)
      end
     end
     indices[page.component_offset]=true
    end
    local n=0;for _ in pairs(indices)do n=n+1 end
    counts[spec.KEY]={entities=#view.pages,records=n,fields=#spec.FIELDS}
    -- Change every exposed member, preserving padding and neighbouring records in the native block.
    local page=view.pages[1];e.select(page)
    local before=e.read_bytes(table_.copies[1]+24,table_.payload)
    local mask={};local offsets={}
    for _,field in ipairs(spec.FIELDS)do
     local part=assert(page.by_id[field[9]and field[9].id or field[1]])
     local row=part.row;local native=part.field
     local width=native.storage=='u8'and 1 or 4
     assert(native.storage==(field[3]=='enum'and'u32'or field[3]),'native storage changed')
     local value=native.storage=='u8'and 255 or native.storage=='f32'and -123.5
      or field[1]=='status_effect'and 64 or 4294967295
     e.change(row,0,false,value);assert(e.read(native)==value,field[1]..': edit refused')
     offsets[native.offset]={storage=native.storage,value=value}
     for j=native.offset,native.offset+width-1 do mask[j]=true end
     edited[#edited+1]={page=page,row=row}
    end
    local bytes=e.read_bytes(table_.copies[1]+24,table_.payload)
    for i=0,#bytes-1 do if not mask[i]then assert(bytes:byte(i+1)==before:byte(i+1),'adjacent byte changed')end end
    -- Enemy aliases must use the exact same radius field; changing it here is immediately visible there.
    local id=spec.KEY=='jammer'and'jam_radius'or'scramble_radius'
    for _,enemy in ipairs(e.weapons)do
     if enemy.enemy and enemy.by_id[id]and enemy.by_id[id].field==page.by_id[id].field then
      assert(e.row_value(enemy.by_id[id].row)==-123.5);sync=sync+1
     end
    end
    counts[spec.KEY].offsets=offsets
   end
   assert(sync>0,'no enemy alias synchronization exercised')
   assert(e.save(),'portable config save failed')
   local G=require('gamedata');local seen={}
   for _,change in ipairs(H.diff())do
    local sealed=assert(H.build(change));local p,n=assert(G.open_sealed(sealed))
    assert(G.murmur64(p,n)==change.hash,'authenticated write changed file hash')
    for _,header in ipairs(G.headers(p,n))do
     for _,spec in ipairs(A.SPECS)do if header.type==spec.HASH then
      local at=p+header.at+24;local data=counts[spec.KEY];seen[spec.KEY]=true
      for off,v in pairs(data.offsets)do
       local ctype=v.storage=='f32'and'float *'or v.storage=='u8'and'uint8_t *'or v.storage=='i32'and'int32_t *'or'uint32_t *'
       assert(tonumber(ffi.cast(ctype,at+off)[0])==v.value,'encrypted readback mismatch')
      end
     end end
    end
    G.free(p) -- H.build consumes change.plain.
   end
   assert(seen.jammer and seen.scrambler)
   for _,q in ipairs(edited)do e.reset_row(q.page,q.row)end
   assert(#H.diff()==0,'reset did not restore exact original bytes')
   -- Both directions, for every actual enemy with these aliases, after generic construction.
   for _,enemy in ipairs(e.weapons)do if enemy.enemy then
    for _,spec in ipairs(A.SPECS)do
     local id=spec.KEY=='jammer'and'jam_radius'or'scramble_radius'
     local old=enemy.by_id[id]
     local view=e.MOD.weapon_component_views[spec.KEY]
     local generic=view.by_entity[enemy.hash]
     if old and generic then
      generic.ensure_rows();assert(old.field==generic.by_id[id].field)
      e.select(enemy);e.change(old.row,0,false,77.25)
      assert(e.row_value(generic.by_id[id].row)==77.25);e.reset_row(enemy,old.row)
     end
    end
   end end
   assert(#H.diff()==0,'reverse synchronization left edits')
   for _,data in pairs(counts)do data.offsets=nil end
   local out=assert(io.open(TEST_WORK..'/validation.json','wb'));out:write(require('json_data').encode(counts));out:close()
   state.nav_open(parent.id,sub);e.click('cat:StratagemScramblerComponents')
   local page=e.MOD.weapon_component_views.scrambler.pages[1];e.select(page)
   e.MOD.nav.sync();e.ui.scroll=1;e.ui.message=nil;e.ui.version=e.ui.version+1
   phase=1
  elseif phase==1 and state.phase=='ready'then
   assert(state.ui_errors==0,'interference UI failed')
   local e=TEST_PARAMETERS;if not e.ui.gui or #e.ui.gui.items==0 then return true end
   S.save_bmp(TEST_WORK..'/scrambler.bmp')
   e.click('cat:StratagemBlockerComponents');e.select(e.MOD.weapon_component_views.jammer.pages[1])
   e.ui.gui.items={};e.render(S.w,S.h);S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/blocker.bmp')
   phase=2;return false
  end
 end
 return true
end
S.present=function()end;SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS interference components: full native layout, groups, navigation, shared enemy fields, native bounds, byte isolation, portable config, authenticated write/readback, reset, GDI rendering; no game writes')
]==]
assert(loadstring(prefix..checks,'@interference_components_host'))()
