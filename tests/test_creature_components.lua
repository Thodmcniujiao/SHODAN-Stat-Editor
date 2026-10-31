local D=require('demolition');local V=require('component_view');local C=require('creature_components')
local Editor=require('stratagem_entity_editor')
local f=assert(io.open(TEST_FIXTURES..'/dl_library.dl_typelib','rb'));local schemas=D.schemas(f:read('*a'));f:close()
assert(#C.SPECS==10 and #C.SUBS.creature==11 and #C.SUBS.character==1)
assert(C.TAB_LABELS.CreatureUnitComponents[2]=='单位'and C.TAB_LABELS.CreatureUnitComponents[3]=='單位')
-- Compare component identities, not display labels: AI and creature tabs must be disjoint.
local by_slot={};for _,s in ipairs(require('ai_components').SPECS)do by_slot[s.SLOT]=s end
for _,s in ipairs(C.SPECS)do
 assert(s.TYPE~='AvatarComponentData','Character data already exposes Avatar')
 by_slot[s.SLOT]=s
end
local creature_types={}
for _,slot in ipairs(C.SUBS.creature)do
 local s=assert(by_slot[slot]);assert(not creature_types[s.HASH],'duplicate creature component')
 creature_types[s.HASH]=true
 assert(s.TYPE~='AvatarComponentData'and s.TYPE~='CharacterVoiceComponentData')
end
for _,slot in ipairs(require('ai_components').SUBS.ai)do
 assert(not creature_types[assert(by_slot[slot]).HASH],'component also listed under AI settings')
end
local fields=0;local slots={}
for _,s in ipairs(C.SPECS)do
 assert(V.check_layout(s,schemas,s.HASH),s.TYPE)
 assert(s.STRICT and not slots[s.SLOT]);slots[s.SLOT]=true
 local reflected=Editor.reflect({s.HASH,s.SIZE,s.TYPE},schemas)
 local leaves={};for _,r in ipairs(reflected.FIELDS)do leaves[r[2]..':'..r[3]]=true end
 local ids,bytes={},{}
 for _,r in ipairs(s.FIELDS)do
  local storage=r[3]=='flag'and'u8'or r[3]
  assert(leaves[r[2]..':'..storage]or r[3]:match('^bit'),s.TYPE..': not an inline field '..r[1])
  assert(not ids[r[9].id],s.TYPE..': duplicate saved ID');ids[r[9].id]=true
  local size=r[3]=='u64'and 8 or(r[3]=='flag'or r[3]=='u8'or r[3]=='i8'or r[3]:match('^bit'))and 1 or r[3]=='u16'and 2 or 4
  assert(r[2]>=0 and r[2]+size<=s.SIZE)
  if not r[3]:match('^bit')then for at=r[2],r[2]+size-1 do assert(not bytes[at],s.TYPE..': overlapping fields');bytes[at]=true end end
 end
 fields=fields+#s.FIELDS
end
print('PASS: '..#C.SPECS..' complete creature component layouts; '..fields..' unique inline fields; saved IDs, bounds, non-overlap, descriptor exclusion and suppression navigation')
