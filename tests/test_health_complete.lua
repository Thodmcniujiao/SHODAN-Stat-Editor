-- Full Health schema, editor ownership and authenticated readback. Isolated buffers/profile only.
local f=assert(io.open(TEST_ROOT..'/tests/test_editor_demolition_sync.lua','rb'))
local source=f:read('*a');f:close()
local start=assert(source:match('^(.-)local weapon=assert'))
start=start:gsub('SHODAN_DEMOLITION_BRIDGE=bridge','SHODAN_DEMOLITION_BRIDGE=bridge;SHODAN_COMPONENT_CATALOG_SOURCE=model',1)
start=start:gsub('MOD=MOD,','MOD=MOD,tables=tables,',1)
local checks=[==[
local C=require('health_components');local spec=C.SPEC;local health=state.health_components()
assert(health.full,health.why);assert(#spec.FIELDS==6088 and #health.pages==506)
assert(C.check_layout(model.schemas,spec.HASH))
-- Compare every generated leaf to the actual native type library, not just the total count.
local leaves={}
local function walk(tid,base)
 for _,m in ipairs(model.schemas[tid].members)do
  local count=m.atom==2 and m.count or 1
  local stride=m.size/count
  for i=0,count-1 do
   local off=base+m.offset+i*stride
   if m.storage==20 then walk(m.type,off)
   else
    local bit=m.atom==3 and math.floor(m.count/256)or nil
    local key=off..(bit and(':'..bit)or'');assert(not leaves[key]);leaves[key]={m.storage,m.size/count}
   end
  end
 end
end
walk(model.schemas[spec.HASH].members[2].type,0)
local ids={}
for _,s in ipairs(spec.FIELDS)do
 local bit=s[3]:match('^bit(%d)$');local key=s[2]..(bit and(':'..bit)or'')
 local leaf=assert(leaves[key],'generated field has no native member: '..s[1])
 local expect=({i32=2,f32=8,u32=6,u64=7,flag=4,enum=16})[s[3]]or(bit and 4)
 assert(expect==leaf[1]or(s[3]=='i32'and leaf[1]==12),s[1]..': wrong storage')
 leaves[key]=nil;assert(not ids[s[9].id],s[9].id);ids[s[9].id]=true
 assert(s[9].bucket and s[6]and s[8]and s[9].id)
end
assert(not next(leaves),'native fields omitted')
-- Reject same-size type changes and relocated packed bits before offering the complete editor.
local native=model.schemas[model.schemas[spec.HASH].members[2].type]
local saved=native.members[1].storage;native.members[1].storage=8
assert(not C.check_layout(model.schemas,spec.HASH));native.members[1].storage=saved
local effect=model.schemas[0x10CEE58B];local packed=effect.members[#effect.members]
saved=packed.count;packed.count=1281;assert(not C.check_layout(model.schemas,spec.HASH));packed.count=saved
assert(C.check_layout(model.schemas,spec.HASH))
local lazy=0;for _,p in ipairs(health.pages)do if not p.rows_built then lazy=lazy+1 end end
assert(lazy>450,'full Health rows eagerly allocated for the entire catalog')
local enemy=assert(E.by_hash.F79CD8BB654397DF)
local page=assert(health.by_entity.F79CD8BB654397DF)
page.ensure_rows()
if #page.all_component_rows~=6088 then
 local got={};for _,r in ipairs(page.all_component_rows)do got[r.id]=true end
 for _,s in ipairs(spec.FIELDS)do if not got[s[9].id]then print('MISSING',s[1],s[2],s[3],s[9].id)end end
 print('ACTUAL HEALTH ROWS',#page.all_component_rows)
end
assert(#page.all_component_rows==6088,'a readable field was dropped')
local by_path={}
for _,r in ipairs(page.all_component_rows)do
 assert(r.health_path and r.health_group)
 assert(E.row_value(r)~=nil,r.id)
 by_path[r.health_path]=r
end
assert(page.by_id.health.field==enemy.by_id.health.field)
assert(page.by_id.zone0_health.field==enemy.by_id.zone0_health.field)
assert(page.by_id.health.field.storage=='i32')
local part_groups=0
for _,g in ipairs(page.component_groups)do if g.type:match('^Health:zone%d+$')then part_groups=part_groups+1 end end
assert(part_groups==38 and #page.rows==#page.component_groups,'fixed or inactive zone slots are inaccessible')
local at=E.tables[spec.HASH].copies[1]+24+page.health_offset
local initial=ffi.string(ffi.cast('const void *',at),spec.SIZE)
local function change(path,value)
 local r=assert(by_path[path],path);E.ui.weapon=page;E.change(r,0,false,value)
 assert(E.row_value(r)==value,path..' failed to edit');return r
end
change('health',12345);assert(E.row_value(enemy.by_id.health.row)==12345)
local n=0;for _,o in ipairs(E.overrides())do if o.id=='health'and o.hash==enemy.hash then n=n+1 end end
assert(n==1,'canonical enemy Health owner duplicated')
change('constitution',-777);assert(E.row_value(page.by_id.bleed.row)==-777,'signed health did not round-trip')
change('health_changerate_disabled',0)
change('regeneration_segments',7)
change('default_damageable_zone_info.causes_death_on_downed',1)
change('default_damageable_zone_info.child_zones[15]',0xDEADBEEF)
change('damageable_zones[37].info.health',-123)
change('damageable_zones[37].actors[23]',0xABCD1234)
change('damageable_zones[37].info.health_event_triggers[3].reverse_event_sound',0x89ABCDEF)
change('element_damage[3].multiplier',3.25)
change('decay.max_delay',123.5)
change('on_death_destruction_level',9)
change('death_propagation',3)
change('death_animation_sound[7].unk_uint32_r0x0004',0x12345678)
-- Every resource hash remains exact across both uint32 halves; packed bits preserve adjacent flags/padding.
local hash=assert(by_path['on_death_effect.particle_effect']);assert(hash.hash64)
assert(E.MOD.stratagem.set_hash(page,hash,'0x3F8000013F800001'))
local effect_row=assert(by_path['on_death_effect.effect_flags.linked'])
local off=effect_row.parts[1].field.offset-page.health_offset
local old=initial:byte(off+1)
change('on_death_effect.effect_flags.linked',1-math.floor(old/2)%2)
local now=ffi.string(ffi.cast('const void *',at),spec.SIZE)
assert(now:byte(off+1)==old+(math.floor(old/2)%2==0 and 2 or -2),'packed-bit edit changed adjacent flags')
for _,ofs in ipairs({443,442,451,452,453,454,455,519,22093,22094,22095})do
 assert(now:byte(ofs+1)==initial:byte(ofs+1),'padding changed at '..ofs)
end
-- Presets and full-page resets traverse collapsed groups, including the last unnamed slot.
assert(page.health_enemy_scope and E.MOD.is_enemy_value(page.hash))
assert(E.presets.select_scope('enemy'));local preset=assert(E.presets.new_full_preset());assert(E.presets.finish_rename(false));assert(E.save_config())
E.reset_weapon(page);assert(ffi.string(ffi.cast('const void *',at),spec.SIZE)==initial,'collapsed reset omitted fields')
assert(E.presets.load_full_preset(preset))
assert(E.row_value(page.by_id.health.row)==12345)
assert(E.row_value(by_path['damageable_zones[37].actors[23]'])==0xABCD1234)
assert(E.MOD.stratagem.hash_text(hash)=='4575657226768744449')
local expected=ffi.string(ffi.cast('const void *',at),spec.SIZE)
local changes=H.diff();assert(#changes==1 and #changes[1].floats==0,'Health ID/hash words became float salts')
changes[1].demolition_schemas=model.schemas
local sealed,why=H.build(changes[1]);assert(sealed,why)
local plain,size=G.open_sealed(sealed);assert(plain and G.murmur64(plain,size)==changes[1].hash)
local found=false
for _,h in ipairs(G.headers(plain,size))do if h.type==spec.HASH then
 assert(ffi.string(plain+h.at+24+page.health_offset,spec.SIZE)==expected,'Health bytes changed in authenticated output');found=true
end end
assert(found);G.free(plain)
E.reset_weapon(page);assert(ffi.string(ffi.cast('const void *',at),spec.SIZE)==initial)
assert(#H.diff()==0)
-- A separate uncatalogued entity gets the same complete view without expanding every page.
local other
for _,p in ipairs(health.pages)do if p~=page and not p.rows_built then other=p;break end end
other.ensure_rows();assert(#other.all_component_rows==6088)
assert(health.pages[1].ensure_rows)
-- Actual Chinese GDI renderer: summary, default body damage, and the last zone's parameters.
local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=1272,-1296,1,32
S.w,S.h=1272,1296
local bits=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,bits,nil,0);assert(dib~=nil)
local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',bits[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end
local function render(name)
 E.ui.version=E.ui.version+1;E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..name..'.bmp')
end
E.settings.component_category='all';E.settings.component_show_missing=false;E.select_weapon(page);E.MOD.nav.sync();E.ui.message=nil
render('health-groups')
E.ui.expanded_components[page.hash..':Health:default']=true;page.sync_rows('Health:default')
render('health-default')
E.ui.expanded_components[page.hash..':Health:default']=nil
E.ui.expanded_components[page.hash..':Health:zone37']=true;page.sync_rows('Health:zone37')
for i,r in ipairs(page.rows)do if r.health_path and r.health_path:find('damageable_zones[37].',1,true)then E.ui.scroll=i;break end end
render('health-last-zone')
E.ui.scroll=E.ui.last_page or 1;E.ui.row=#page.rows;E.tick();assert(E.ui.last_visible==#page.rows,'final rows unreachable')
gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib);gdi.DeleteDC(S.dc)
print('PASS: 6088 native fields, 38 complete zone slots, 506 lazy entity pages, strict signed/nested/packed storage, all categories, canonical enemy sync, exact hashes, last-slot edits, collapsed resets/presets, authenticated byte readback and native Chinese UI; no game writes')
]==]
assert(loadstring(start..checks,'@health-complete-integration'))()
