local D=require('demolition');local V=require('component_view');local N=require('component_names')
local Data=require('reference_component_names');local Editor=require('stratagem_entity_editor')
local f=assert(io.open(TEST_FIXTURES..'/dl_library.dl_typelib','rb'));local schemas=D.schemas(f:read('*a'));f:close()
local roots={};for _,r in ipairs(require('stratagem_entity_specs').ROOTS)do roots[r[1]]=r end
local positions,kinds=0,0
for kind,data in pairs(Data.TYPES)do
 assert(N.signature(schemas,kind)==data.signature,string.format('%08X signature differs',kind))
 local spec=assert(Editor.reflect(roots[kind],schemas));local leaves={}
 for _,r in ipairs(spec.FIELDS)do leaves[r[2]..':'..r[3]]=true end
 for key,entry in pairs(data.fields)do
  assert(leaves[key],string.format('%08X field %s is not an inline leaf',kind,key))
  assert(entry.evidence=='struct'or entry.evidence=='anchor')
  assert(entry.offset>=0 and entry.offset<data.size)
  positions=positions+1
 end
 kinds=kinds+1
end
-- A schema change must disable the supplement, including changes in nested types.
local changed={};for k,v in pairs(schemas)do changed[k]=v end
local unit_kind=0x4437574D;local row=schemas[unit_kind].members[2].type
changed[row]={size=schemas[row].size,members={}}
for i,v in ipairs(schemas[row].members)do
 local m={};for k,x in pairs(v)do m[k]=x end;changed[row].members[i]=m
end
changed[row].members[1].storage=6
assert(not N.lookup(changed,unit_kind),'names survived a changed field type')
assert(not Data.TYPES[0x5224F28D],'ambiguous changed MeleeAttack primitives were guessed')
local totals,resolved={},{};local renamed=0
for _,module in ipairs({'weapon_components','orbital_components','mission_components','hellpod_components',
 'enemy_components','creature_components','stratagem_entity_specs','health_schema','drown_components','shield_components',
 'throwable_components','thrower_components','minefield_components','mine_spawner_components','faction_components',
 'mount_components','inventory_components','sensor_eye_components','turret_components','eagle_components',
 'eagle_spawner_components','spawn_components','preload_components'})do
 local source=require(module)
 local specs=source.SPECS or(source.SPEC and{source.SPEC})or{}
 if source.FIELDS and source.SIZE and type(source.FIELDS[1][8])=='table'then
  if module=='shield_components'then source=setmetatable({TYPE='ShieldComponentData',HASH=0x5154DB66},{__index=source})end
  specs={source}
 end
 for _,spec in ipairs(specs)do
  local before={}
  for i,r in ipairs(spec.FIELDS)do
   local extra={};for k,v in pairs(r[9]or{})do extra[k]=v end
   before[i]={r[1],r[2],r[3],r[4],r[8],extra}
  end
  local count=N.apply(spec,schemas,spec.HASH)
  for _,r in ipairs(spec.FIELDS)do if r[9]and r[9].resolved_name then
   local key=tostring(spec.HASH)..':'..r[2]..':'..r[3]
   if not resolved[key]then resolved[key]=true;renamed=renamed+1;totals[spec.TYPE]=(totals[spec.TYPE]or 0)+1 end
  end end
  for i,r in ipairs(spec.FIELDS)do
   local b=before[i]
   for j=1,4 do assert(r[j]==b[j],spec.TYPE..' changed field identity or grouping')end
   assert(r[8]==b[5],spec.TYPE..' changed numeric limits')
   for k,v in pairs(b[6])do assert(r[9][k]==v,spec.TYPE..' changed old metadata '..k)end
  end
 end
end
local unit=require('creature_components').SPECS[1]
assert(unit.FIELDS[1][6]=='单位资源路径'and unit.FIELDS[1][9].resolved_name=='unit_path')
local saw_group=false;for _,g in pairs(unit.GROUP)do if g.name[2]=='生成时隐藏的可见组'then saw_group=true end end
assert(saw_group,'Unit array group remains unknown')
-- Good labels and wrong storage are never replaced even when an offset matches.
local good={SIZE=unit.SIZE,HASH=unit.HASH,GROUP={},FIELDS={{'stable_id',0,'u64','g','Existing name','现有名称','現有名稱',V.R.hash,{id='stable_id'}}}}
assert(N.apply(good,schemas,unit_kind)==0 and good.FIELDS[1][6]=='现有名称')
good.FIELDS[1][3]='u32';good.FIELDS[1][5]='Unknown';good.FIELDS[1][6]='未知'
assert(N.apply(good,schemas,unit_kind)==0 and good.FIELDS[1][6]=='未知')
local J=require('json_data');local I=require('install');I.mkdirs(TEST_WORK)
local out=assert(io.open(TEST_WORK..'/name-coverage.json','wb'));out:write(J.encode({reference_positions=positions,
 component_tables=kinds,supplemented_fields=renamed,by_type=totals},true));out:close()
print('PASS: '..positions..' inline reference positions in '..kinds..' component tables; '..renamed..' display names/descriptions supplemented; IDs/storage/offsets/ranges preserved, changed schemas and ambiguous primitives rejected')
