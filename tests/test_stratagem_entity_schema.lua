local D=require('demolition');local V=require('component_view')
local Editor=require('stratagem_entity_editor');local Data=require('stratagem_entity_specs')
local f=assert(io.open(TEST_FIXTURES..'/dl_library.dl_typelib','rb'));local schemas=D.schemas(f:read('*a'));f:close()
local types={};local fields,descriptors=0,0
for _,root in ipairs(Data.ROOTS)do
 assert(not types[root[1]],'duplicate component kind');types[root[1]]=true
 local spec,readonly,refs=assert(Editor.reflect(root,schemas))
 assert(V.check_layout(spec,schemas,root[1]),root[3])
 local ids={}
 for _,field in ipairs(spec.FIELDS)do
  local storage=field[3];local size=storage=='u64'and 8 or(storage=='u8'or storage=='i8'or storage:match('^bit%d'))and 1 or storage=='u16'and 2 or 4
  assert(field[2]>=0 and field[2]+size<=root[2],root[3]..' field outside record')
  assert(not ids[field[9].id],root[3]..' repeated field ID');ids[field[9].id]=true
 end
 for _,d in ipairs(readonly)do assert(d.offset>=0 and d.offset+d.size<=root[2],root[3]..' descriptor outside record')end
 fields=fields+#spec.FIELDS;descriptors=descriptors+#readonly
end
for _,spec in ipairs(Data.SPECS)do
 assert(V.check_layout(spec,schemas,spec.HASH),spec.TYPE)
 local reflected,readonly=Editor.reflect({spec.HASH,spec.SIZE,spec.TYPE},schemas)
 -- A named field must be one of the current library's editable leaves; descriptors are excluded.
 local leaves={};for _,f in ipairs(reflected.FIELDS)do leaves[f[2]..':'..f[3]]=true end
 for _,f in ipairs(spec.FIELDS)do
  local storage=f[3]=='flag'and'u8'or f[3]
  assert(leaves[f[2]..':'..storage]or f[3]:match('^bit'),spec.TYPE..' named field is not an inline native member: '..f[1])
 end
end
print('PASS: '..#Data.ROOTS..' actual keyed ECS layouts; '..fields..' editable leaves and '..descriptors..' read-only descriptors; named vehicle/backpack specs exclude pointer words')
