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

local Q=require('spawn_queue_components');local SP=require('spawn_components');local V=require('component_view')
assert(#SP.SPECS==4 and #SP.SUBS.spawn==4)
local function rows(page)if page.ensure_rows then page.ensure_rows()end;return page.rows end
local function row(page,id)for _,r in ipairs(rows(page))do if r.id==id then return r end end;error('missing '..id)end
local views=E.MOD.weapon_component_views
local squad=assert(views.spawn_squad);local producer=assert(views.spawn_producer)
assert(#Q.SPECS[2].FIELDS==54)
assert(squad.full and producer.full,tostring(squad.why)..' / '..tostring(producer.why))
assert(#squad.pages==21 and #producer.pages==33,'missing native spawning records')
local slot_count=0
for _,page in ipairs(squad.pages)do
 assert(#rows(page)==21)
 for i=1,6 do
  local r=row(page,'member_'..i..'_hash');assert(r.hash64 and #r.parts==2)
  assert(r.parts[1].field.offset==page.component_offset+16+(i-1)*16)
  assert(r.parts[2].field.offset==r.parts[1].field.offset+4)
  assert(row(page,'member_'..i..'_count').parts[1].field.offset==r.parts[1].field.offset+8)
  slot_count=slot_count+1
 end
end
for _,p in ipairs(producer.pages)do
 assert(#rows(p)==#Q.SPECS[2].FIELDS,'producer fields missing')
 for _,r in ipairs(p.rows)do assert(E.row_value(r)~=nil,r.id)end
end
print('Native squad pages / member slots / producer pages / producer fields:',#squad.pages,slot_count,#producer.pages,#Q.SPECS[2].FIELDS)
-- Same-width storage changes are rejected too; uint64 member hashes must not become floats.
local meta=model.schemas[model.schemas[Q.SPECS[1].HASH].members[2].type]
local inner=model.schemas[meta.members[4].type];local saved=inner.members[1].storage
inner.members[1].storage=8;assert(not V.check_layout(Q.SPECS[1],model.schemas,Q.SPECS[1].HASH));inner.members[1].storage=saved
assert(V.check_layout(Q.SPECS[1],model.schemas,Q.SPECS[1].HASH))
-- Current faction filtering must list both the HiveMind and the new templates.
for _,kind in ipairs({'spawn_hive_mind','spawn_squad','spawn_producer'})do
 local list=E.MOD.component_catalog:list(kind,'terminids',false,'',E.settings.tr)
 assert(#list>0,kind..' hidden by faction category');print('Terminid filter '..kind..':',#list)
end
local page=assert(squad.by_entity['704476220F0BD7B6']);local hash=row(page,'member_6_hash');local count=row(page,'member_6_count')
local t=E.tables[Q.SPECS[1].HASH];local at=t.copies[1]+24+page.component_offset
local initial=ffi.string(ffi.cast('const void *',at),112)
local lo,hi=E.MOD.stratagem.schema.parse_u64('0xFFFFFFFFFFFFFFFF');assert(lo==4294967295 and hi==4294967295)
assert(not E.MOD.stratagem.schema.parse_u64('0x10000000000000000'))
assert(not E.MOD.stratagem.schema.parse_u64('0xNOPE'))
E.select_weapon(page);E.ui.weapon=page
local hash_index;for i,r in ipairs(page.rows)do if r==hash then hash_index=i end end;assert(hash_index)
E.click('value:'..hash_index);assert(E.ui.value)
E.ui.value.text='0x10000000000000000';assert(not state.commit_value()and E.ui.value)
E.ui.value.text='0xD1E990BAF22D5A52';assert(state.commit_value())
assert(E.MOD.stratagem.hash_text(hash)=='15125779956101896786')
E.change(count,0,false,17);assert(E.row_value(count)==17)
local now=ffi.string(ffi.cast('const void *',at),112)
local off=16+5*16;assert(now:sub(1,off)==initial:sub(1,off),'queue edit changed preceding slots')
assert(now:sub(off+13)==initial:sub(off+13),'queue edit changed attachment node')
TEST_PRESETS_HELPER.save(E,page,1);assert(E.save_config())
E.reset_weapon(page);assert(ffi.string(ffi.cast('const void *',at),112)==initial)
TEST_PRESETS_HELPER.load(E,page,1);assert(E.row_value(count)==17 and E.MOD.stratagem.hash_text(hash)=='15125779956101896786')
E.reset_weapon(page);assert(ffi.string(ffi.cast('const void *',at),112)==initial)
-- Two words which resemble floating point values must remain exact through authentication/repacking.
assert(E.MOD.stratagem.set_hash(page,hash,'0x3F8000013F800001'));E.change(count,0,false,7)
local queue_expected=ffi.string(ffi.cast('const void *',at),112)
local pp=producer.pages[1];local cap=row(pp,'production_queue_limit');local pc=row(pp,'spawn_count');local cooldown=row(pp,'production_cooldown')
E.ui.weapon=pp;E.change(cap,0,false,99);E.change(pc,0,false,12);E.change(cooldown,0,false,1.25)
assert(E.row_value(cap)==99 and E.row_value(pc)==12 and E.row_value(cooldown)==1.25)
local changes=H.diff();assert(#changes==1 and #changes[1].floats==0,'spawning IDs/hashes used as float correction candidates')
changes[1].demolition_schemas=model.schemas
local sealed,why=H.build(changes[1]);assert(sealed,why)
local plain,n=G.open_sealed(sealed);assert(plain and G.murmur64(plain,n)==changes[1].hash)
for _,head in ipairs(G.headers(plain,n))do if head.type==Q.SPECS[1].HASH then
 assert(ffi.string(plain+head.at+24+page.component_offset,112)==queue_expected,'repacked member hash/count differs')
end end
G.free(plain);E.reset_weapon(page);E.reset_weapon(pp);assert(#H.diff()==0)
-- Render the actual Enemy / Spawn tabs, not a separate mock interface.
local function render(w,name)
 E.settings.lang='zh-Hans';S.lang=function()return E.settings.lang end;S.w,S.h=1272,1296
 E.settings.component_category='terminids';E.select_weapon(w);E.settings.component_show_missing=false;E.MOD.nav.sync();E.ui.message=nil
 assert(E.ui.nav.page=='enemies' or E.ui.nav.page=='enemy','spawn page navigation left Enemy settings')
 local info=ffi.new('host_bitmapinfo');info.size=ffi.sizeof(info);info.width,info.height,info.planes,info.bits=S.w,-S.h,1,32
 local ptr=ffi.new('void *[1]');local dib=gdi.CreateDIBSection(S.dc,info,0,ptr,nil,0);assert(dib~=nil)
 local previous=gdi.SelectObject(S.dc,dib);S.bits=ffi.cast('uint32_t *',ptr[0]);gdi.SetBkMode(S.dc,1);gdi.SetTextAlign(S.dc,24)
 E.ui.version=E.ui.version+1;E.tick();S.sleep(1650);E.tick();assert(state.ui_errors==0)
 S.paint_guis({255,12,15,19});S.save_bmp(TEST_WORK..'/'..name..'.bmp')
 E.ui.scroll=E.ui.last_page or 1;E.ui.row=#w.rows;E.tick();assert(E.ui.last_visible==#w.rows)
 gdi.SelectObject(S.dc,previous);gdi.DeleteObject(dib)
end
render(page,'squad-queue');render(pp,'production-queue')
print('PASS: native squad/production tables, 126 exact uint64 slots and quantities, strict layout checks, working faction filters, hex input, byte isolation, canonical presets, authenticated readback, native UI; no game writes')

]==]
assert(loadstring(start..checks,"@spawn-queue-integration"))()
