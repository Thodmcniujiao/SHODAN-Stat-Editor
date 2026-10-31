local f=assert(io.open(TEST_ROOT..'/tests/test_stratagem_editor.lua','rb'))
local prefix=assert(f:read('*a'):match('^(.-)local checks='));f:close()
local start=assert(loadstring(prefix..'\nreturn start'))()
start=start:gsub('MOD=MOD,','MOD=MOD,field_at=field_at,read_field=read_field,write_field=write_field,keyboard=keyboard,finish_value=finish_value,',1)
local checks=[==[
local N=E.MOD.numeric
local page=assert(E.MOD.component_catalog.by_entity.health.EF79CD8BB654397DF)
page.ensure_rows()
if page.component_groups then for _,g in ipairs(page.component_groups)do g.load();E.ui.expanded_components[page.hash..':'..g.type]=true end;page.sync_rows()end
local main,small
for _,row in ipairs(page.rows)do
 for _,p in ipairs(row.parts)do
  if p.field.offset==E.tables[p.field.kind].index[page.key]and p.field.storage=='i32'then main=row end
  if not small and #row.parts==1 and p.field.storage=='f32'and not row.choice then small=row end
 end
end
assert(main and small,'health rows: main='..tostring(main)..', float='..tostring(small))
local field=main.parts[1].field;local original=E.row_value(main)
local other
for _,row in ipairs(E.by_hash.F79CD8BB654397DF.rows)do
 for _,p in ipairs(row.parts)do if p.field==field then other=row end end
end
assert(other,'original health row not found');N.row(main);N.row(other)
assert(main.min==-2147483648 and main.max==2147483647 and other.max==main.max,'health views use different limits')
E.select_weapon(page);E.change(main,0,false,2147483647);assert(E.row_value(main)==2147483647)
assert(not E.write_field(field,2147483648)and E.read_field(field)==2147483647,'int32 overflow wrapped')
E.select_weapon(E.by_hash.F79CD8BB654397DF);E.change(other,0,false,2000000000)
assert(E.row_value(main)==2000000000,'original editor still applies a tuning cap')
assert(E.write_field(field,original))
E.select_weapon(page);E.reset_row(page,main)
local unsigned
for _,row in ipairs(page.rows)do if #row.parts==1 and row.parts[1].field.storage=='u32'and not row.choice then unsigned=row;break end end
assert(unsigned);local ufield=unsigned.parts[1].field;local uold=E.row_value(unsigned)
E.change(unsigned,0,false,4294967295);assert(E.row_value(unsigned)==4294967295)
assert(not E.write_field(ufield,4294967296)and E.row_value(unsigned)==4294967295)
assert(not E.write_field(ufield,-1)and E.row_value(unsigned)==4294967295)
E.reset_row(page,unsigned);assert(E.row_value(unsigned)==uold)
local float=small.parts[1].field;local before=E.row_value(small)
E.change(small,0,false,-1e25);assert(E.row_value(small)<-1e24,'negative float blocked by a tuning range')
assert(E.write_field(float,N.F32_MAX)and E.read_field(float)==N.F32_MAX)
assert(not E.write_field(float,N.F32_MAX*2)and E.read_field(float)==N.F32_MAX)
local function enter(w,row,text)
 E.select_weapon(w)
 local n;for i,r in ipairs(w.rows)do if r==row then n=i;break end end;assert(n)
 E.ui.value={weapon=w,n=n,text='',fresh=true}
 for c in text:gmatch('.')do S.push_typed(c:byte());E.keyboard(1)end
 assert(E.ui.value.text==text,'input was filtered or truncated: '..text)
 E.finish_value(true)
end
enter(page,small,'2.5e-20');assert(not E.ui.value)
local tiny=E.row_value(small);assert(tiny>0 and tiny<1e-19)
local saved=false
for _,o in ipairs(E.overrides())do
 local w=E.by_hash[o.hash];local p=w and w.by_id[o.id]
 if p and p.field==float then assert(o.value==tiny);saved=true end
end
assert(saved,'small float was dropped by an epsilon threshold')
assert(E.save_config());assert(read(I.home..'/config.txt'):find('e%-20'),'config rounded a tiny float to zero')
TEST_PRESETS_HELPER.save(E,page,'small-float-range');E.change(small,0,false,100)
TEST_PRESETS_HELPER.load(E,page,'small-float-range');assert(E.row_value(small)==tiny,'preset changed float precision')
E.reset_row(page,small);assert(E.row_value(small)==before)
-- Test the real 64-bit ProjectileWeapon entity input, not only the parser.
local weapon,hashrow
for _,w in ipairs(E.MOD.weapon_component_views.projectile_weapon.pages)do
 w.ensure_rows()
 for _,row in ipairs(w.rows)do if row.hash64 then weapon,hashrow=w,row;break end end
 if hashrow then break end
end
assert(hashrow)
local hash_before=E.MOD.stratagem.hash_text(hashrow)
enter(weapon,hashrow,'18446744073709551615')
assert(not E.ui.value and E.MOD.stratagem.hash_text(hashrow)=='18446744073709551615')
TEST_PRESETS_HELPER.save(E,weapon,'full-uint64')
enter(weapon,hashrow,'18446744073709551616')
assert(E.ui.value and E.MOD.stratagem.hash_text(hashrow)=='18446744073709551615','uint64 overflow changed bytes')
E.ui.value=nil;enter(weapon,hashrow,'0x1234567890ABCDEF')
assert(not E.ui.value and E.MOD.stratagem.hash_text(hashrow)==require('name_ids').decimal('1234567890ABCDEF'))
TEST_PRESETS_HELPER.load(E,weapon,'full-uint64')
assert(E.MOD.stratagem.hash_text(hashrow)=='18446744073709551615','preset rounded the uint64 halves')
assert(E.MOD.stratagem.set_hash(weapon,hashrow,hash_before))
assert(#H.diff()==0,'test did not restore private game memory')
gdi.DeleteDC(S.dc)
print('PASS: shared health limits/int32 endpoints, float32 signed extremes and tiny scientific values, config/preset precision, actual 20-digit uint64/hex keyboard input and overflow protection; no game writes')
]==]
assert(loadstring(start..checks,'@numeric-limits-ui'))()
