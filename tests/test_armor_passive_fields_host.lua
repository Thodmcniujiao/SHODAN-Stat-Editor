local f=assert(io.open(TEST_ROOT..'/tests/test_parameter_preferences_host.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local phase, changed, began'));f:close()
prefix=prefix:gsub('save=save_config,','passive_tables=tables,passive_kind=KINDS[TYPES.passive],render=draw,save=save_config,')
local checks=[==[
local mode=os.getenv('SHODAN_ARMOR_FIELDS_PHASE')or'setup'
local phase,began=0,tonumber(ffi.C.GetTickCount64())
local function checkpoint(name)
 local f=assert(io.open(TEST_WORK..'/armor-test-stage.txt','wb'));assert(f:write(mode..': '..name));f:close()
end
local function row(page,id)return assert(page.by_id[id],'missing armor field '..id).row end
local function number(e,p,id)return e.row_value(row(p,id))end
local function change(e,p,id,v)e.select(p);e.change(row(p,id),0,false,v)end
S.pump=function()
 assert(tonumber(ffi.C.GetTickCount64())-began<90000,'armor fields UI timeout')
 local state=rawget(_G,'ShodanStatEditor')
 if state then
  assert(state.phase~='gave_up',state.status)
  if state.phase=='ready'and phase==0 then
   checkpoint('ready')
   local e=assert(TEST_PARAMETERS);local A=require('armor_passive_components')
   local pages,mods,stats,fields=0,0,0,0
   assert(A.check_layout(SHODAN_COMPONENT_CATALOG_SOURCE.schemas))
   for _,p in ipairs(e.weapons)do if p.passive then
    pages=pages+1;local index=e.passive_tables[p.passive].index;mods=mods+#index.mods;stats=stats+#index.stats
    for _,r in ipairs(e.MOD.parameter_rows(p))do if r.armor_passive_path then fields=fields+1 end end
   end end
   assert(pages==32 and mods==78 and stats==9 and fields==467,'native armor fields are missing: '..pages..'/'..mods..'/'..stats..'/'..fields)
   local feet=assert(e.by_hash.FFFFFFFE0000001F);local siege=assert(e.by_hash.FFFFFFFE00000010)
   local op=row(feet,'mod_AF8B7112_type');local value=row(feet,'mod_AF8B7112')
   if mode=='setup'then
    assert(number(e,feet,'mod_AF8B7112_type')==2 and number(e,feet,'mod_B62B4AFD_type')==0)
    assert(op.label_of():find('倍率',1,true)and row(feet,'mod_B62B4AFD_type').label_of():find('设置',1,true))
    change(e,feet,'passive_unknown_0x30',4294967295)
    assert(number(e,feet,'passive_unknown_0x30')==4294967295);e.reset_row(feet,row(feet,'passive_unknown_0x30'))
    local icon=row(feet,'passive_icon_lo');local before_icon=e.MOD.stratagem.hash_text(icon)
    e.select(feet);assert(e.MOD.stratagem.set_hash(feet,icon,'18446744073709551615'))
    assert(e.MOD.stratagem.hash_text(icon)=='18446744073709551615');e.reset_row(feet,icon)
    assert(e.MOD.stratagem.hash_text(icon)==before_icon)
    change(e,feet,'mod_AF8B7112',1e20)
    assert(math.abs(number(e,feet,'mod_AF8B7112')/1e20-1)<1e-6);e.reset_row(feet,value)
    local shroud=assert(e.by_hash.FFFFFFFE0000002A)
    local a,b=row(shroud,'mod_F0B70521'),row(shroud,'mod_0FF508EB')
    assert(a~=b and #a.parts==1 and #b.parts==1,'independent native modifiers were joined')
    local other_value=e.row_value(b);e.select(shroud);e.change(a,0,false,.125)
    assert(e.row_value(b)==other_value);e.reset_row(shroud,a)
    -- The numeric input path changes only the operation word, leaving its value intact.
    e.select(feet);local n;for i,r in ipairs(feet.rows)do if r==op then n=i end end;assert(n)
    e.click('value:'..n);assert(e.ui.value);e.ui.value.text='1';e.ui.value.fresh=false;assert(state.commit_value())
    assert(number(e,feet,'mod_AF8B7112_type')==1 and number(e,feet,'mod_AF8B7112')==.5)
    change(e,feet,'mod_AF8B7112',-.75)
    assert(number(e,feet,'mod_432A7993_type')==2 and number(e,feet,'mod_B62B4AFD_type')==0)
    change(e,feet,'mod_AF8B7112_type',999);assert(op.label_of():find('未确认',1,true))
    assert(number(e,feet,'mod_AF8B7112')==-.75,'operation changed the raw operand')
    e.reset_row(feet,op);assert(number(e,feet,'mod_AF8B7112_type')==2)
    change(e,feet,'mod_AF8B7112_type',1)
    change(e,siege,'stat_13_add',-2.5);change(e,siege,'stat_13',.75)
    assert(number(e,siege,'stat_13_add')==-2.5 and number(e,siege,'stat_13')==.75)
    assert(math.abs(number(e,siege,'stat_12')-1.2)<.001,'adjacent stat changed')
    local old=row(feet,'mod_AF8B7112_desc');assert(old.parts[1].field.offset==value.parts[1].field.offset+4)
    -- Favorites/custom names keep the native operation field, never duplicate the write.
    e.select(feet);assert(e.MOD.parameters:set(feet,op,'favorite',true))
    assert(e.MOD.parameters:set(feet,op,'name','噪音运算'))
    e.MOD.parameter_refresh(feet);local favorite=assert(feet.rows[1]);assert(favorite.parameter_source==op)
    e.change(favorite,0,false,3);assert(number(e,feet,'mod_AF8B7112_type')==3)
    e.change(favorite,0,false,1);assert(number(e,feet,'mod_AF8B7112')==-.75)
    local preset=assert(e.presets.new_full_preset());assert(e.presets.finish_rename(false))
    checkpoint('preset saved')
    local snapshot=assert(e.presets.library:get(preset));local captured={}
    for _,v in ipairs(snapshot.values)do captured[v.hash..':'..v.id]=v.value end
    assert(captured[feet.hash..':mod_AF8B7112_type']==1 and captured[siege.hash..':stat_13_add']==-2.5)
    e.reset_row(feet,op);e.reset_row(feet,value);e.reset_row(siege,row(siege,'stat_13_add'));e.reset_row(siege,row(siege,'stat_13'))
    assert(e.presets.load_full_preset(preset))
    checkpoint('preset restored')
    assert(number(e,feet,'mod_AF8B7112_type')==1 and number(e,feet,'mod_AF8B7112')==-.75)
    assert(number(e,siege,'stat_13_add')==-2.5 and number(e,siege,'stat_13')==.75)
    -- Prepare the production writer's encrypted output, including a private armor
    -- combination. Nothing is installed into the real game directory.
    local first,second
    for _,a in ipairs(e.weapons)do if a.armor and a.default[1]then
     for _,b in ipairs(e.weapons)do if b.armor and a~=b and b.default[1]==a.default[1]then first,second=a,b;break end end
     if first then break end
    end end
    assert(first and second)
    local G=require('gamedata');local changes=H.diff();assert(H.armor_passives(changes,{[first.armor]={31,16}}))
    checkpoint('combination prepared')
    local assigned,other,records
    records={}
    for _,c in ipairs(changes)do
     checkpoint('building '..c.name)
     local bytes=assert(H.build(c));local p,n=assert(G.open_sealed(bytes));assert(G.murmur64(p,n)==c.hash)
     for _,h in ipairs(G.headers(p,n))do local at=p+h.at+24
      local function u(o)return tonumber(ffi.cast('uint32_t *',at+o)[0])end
      if h.type==0xD9A55AA0 and u(40)==0 then if u(16)==first.armor then assigned=u(28)elseif u(16)==second.armor then other=u(28)end end
      if h.type==A.TYPE then
       local r={mods={},stats={}};records[u(0)]=r
       for i=0,u(24)-1 do local q=at+u(16)+i*16;r.mods[tonumber(ffi.cast('uint32_t *',q)[0])]={type=tonumber(ffi.cast('uint32_t *',q+4)[0]),value=tonumber(ffi.cast('float *',q+8)[0])}end
       for i=0,u(40)-1 do local q=at+u(32)+i*12;r.stats[tonumber(ffi.cast('uint32_t *',q)[0])]={add=tonumber(ffi.cast('float *',q+4)[0]),mul=tonumber(ffi.cast('float *',q+8)[0])}end
      end
     end
     G.free(p) -- H.build already consumes/frees c.plain.
    end
    checkpoint('authenticated output verified')
    assert(assigned and assigned~=first.default[1]and other==second.default[1],'private combination affected another armor')
    for _,id in ipairs({31,assigned})do assert(records[id].mods[0xAF8B7112].type==1 and records[id].mods[0xAF8B7112].value==-.75)end
    for _,id in ipairs({16,assigned})do assert(records[id].stats[13].add==-2.5 and records[id].stats[13].mul==.75)end
    e.settings.cache_clear_on_exit=false;assert(e.save())
    checkpoint('cache saved')
   elseif mode=='reopen'then
    assert(number(e,feet,'mod_AF8B7112_type')==1 and number(e,feet,'mod_AF8B7112')==-.75,'restart lost operation/operand')
    assert(number(e,siege,'stat_13_add')==-2.5 and number(e,siege,'stat_13')==.75,'restart lost separate stat operands')
    assert(e.MOD.parameters:get(feet,op).favorite and e.MOD.parameters:get(feet,op).name=='噪音运算')
   else error('unknown armor test phase')end
   e.select(feet);e.MOD.nav.sync();e.ui.message=nil;e.ui.version=e.ui.version+1;phase=1
  elseif state.phase=='ready'and phase==1 then
   checkpoint('drawn')
   assert(state.ui_errors==0,'armor fields draw error')
   if TEST_PARAMETERS.ui.gui then
    local e=TEST_PARAMETERS;S.save_bmp(TEST_WORK..'/armor-fields-'..mode..'.bmp')
    local feet=e.by_hash.FFFFFFFE0000001F;local target=row(feet,'mod_432A7993_type');local n
    for i,r in ipairs(feet.rows)do if r==target then n=i end end;assert(n)
    local text=table.concat(target.tip_of(),'\n')
    assert(text:find('以原值 100',1,true)and text:find('右侧数字是运算编号',1,true),'missing operation explanation')
    assert(row(feet,'mod_AF8B7112_desc').tip_of()[1]:find('实际效果',1,true))
    e.ui.hover='row:'..n;e.render(S.w,S.h)
    local drawn=false
    for _,item in ipairs(e.ui.gui.items)do if item.text and item.text:find('以原值 100',1,true)then drawn=true end end
    assert(drawn,'hover help was not rendered')
    S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/armor-field-help-'..mode..'.bmp')
    phase=2;return false
   end
  end
 end
 return true
end
S.present=function()end
SHODAN_OFFLINE_LANG='zh-Hans';arg={[1]=panel}
assert(loadfile(app and(app..'/host.lua')or(TEST_ROOT..'/offline/host.lua')))()
assert(phase==2);loadfile=real_loadfile;gdi.DeleteDC(S.dc)
print('PASS armor fields '..mode..': all 467 fields of 32 named passives, independent operations/operands, signed input, favorites, global preset, authenticated private combinations and portable restart; no game writes')
]==]
assert(loadstring(prefix..checks,'@test_armor_passive_fields_host.lua'))()
