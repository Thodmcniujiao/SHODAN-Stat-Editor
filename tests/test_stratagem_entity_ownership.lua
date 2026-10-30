-- Graph topology is independent of ECS ownership: shared targets and cycles
-- must not merge the referenced entities' components into their referrers.
local D=require('demolition');local Data=require('stratagem_entity_specs');local Editor=require('stratagem_entity_editor')
local registry={};for _,r in ipairs(Data.ROOTS)do registry[r[3]]=r end
local selected={assert(registry.VehicleComponentData),assert(registry.MountComponentData),assert(registry.Component_0x3BF780F6)}
local A,B,C,Z=string.char(1)..string.rep('\0',7),string.char(2)..string.rep('\0',7),string.char(3)..string.rep('\0',7),string.char(4)..string.rep('\0',7)
local schemas,tables={},{}
for i,r in ipairs(selected)do
 schemas[r[1]]={members={{atom=2,storage=20,offset=0,count=4,size=64,type=0},{atom=2,storage=20,offset=64,count=4,size=r[2]*4,type=i}}}
 schemas[i]={size=r[2],members={{atom=0,storage=7,offset=0,size=8,type=0,count=1},{atom=0,storage=7,offset=8,size=8,type=0,count=1}}}
 tables[r[1]]={index={}}
end
local vehicle,mount,unnamed=selected[1][1],selected[2][1],selected[3][1]
tables[vehicle].index={[A]=0,[C]=16384}
tables[mount].index={[A]=0,[B]=8192,[C]=16384,[Z]=24576}
tables[unnamed].index={[A]=0,[B]=0,[Z]=24576}
-- A <-> B, B -> Z, C -> Z, Z -> A: a shared target and a real cycle.
local pointers={[0]=B,[8192]=Z,[8200]=A,[16384]=Z,[24576]=A}
local first={hash='1111111111111111',name='Vehicle A',slot='Mechas',stratagem={vehicle=A,payloads={A}},rows={},by_id={},field_keys={}}
local second={hash='2222222222222222',name='Vehicle C',slot='Mechas',stratagem={vehicle=C,payloads={C}},rows={},by_id={},field_keys={}}
local weapons={first,second};local by_hash={[first.hash]=first,[second.hash]=second}
local function wrap(page,groups)
 page.component_groups=groups;page.rows={}
 for _,g in ipairs(groups)do
  g.header={component_modified=function()return false end};page.rows[#page.rows+1]={collapsed_component=true,parts={}}
 end
end
local model=Editor.attach{schemas=schemas,tables=tables,weapons=weapons,by_hash=by_hash,lang=function()return'en'end,
 tab_of=function(p)return p.slot end,wrap=wrap,bytes=function(kind,off,n)return kind==mount and(pointers[off]or string.rep('\0',n))or string.rep('\0',n)end}
assert(model.graph[A][B]and model.graph[B][A]and model.graph[B][Z]and model.graph[C][Z]and model.graph[Z][A])
local target=model.entity_pages.Mechas[Z];assert(target)
local seen={};for _,page in ipairs(model.lists.Mechas)do assert(not seen[page]);seen[page]=true end
assert(#model.lists.Mechas==4,'shared/cyclic entities must have one entry per entity, rather than one copy per path')
assert(target.entity_referrers[first.hash]and target.entity_referrers[second.hash])
for _,page in ipairs(model.pages)do
 local unnamed_seen=false
 for _,g in ipairs(page.component_groups)do
  if g.field_kind then assert(g.entity==D.hex(page.stratagem_entity_key),'component ownership crossed an entity boundary')end
  if g.sub=='unknown'then unnamed_seen=true;assert(g.field_kind==unnamed)
   if page.stratagem_entity_key==A or page.stratagem_entity_key==B then assert(g.shared_count==2 and g.label_of():find('Shared record: 2',1,true),'real shared records must be explicitly labeled')end
  else assert(not unnamed_seen,'a named component was sorted below unnamed components')end
 end
end
local relations
for _,g in ipairs(first.component_groups)do if g.type=='EntityReferences'then relations=g end end
assert(relations)
local both=false;for _,row in ipairs(relations.rows)do if row.entity_target==model.entity_pages.Mechas[B]and row.entity_direction=='both'then both=true end end
assert(both,'mutual references must not be relabeled as parent/child ownership')
print('PASS: shared entity references, mutual references and cycles retain single entity entries, strict component ownership, and a final isolated unnamed-component group')
