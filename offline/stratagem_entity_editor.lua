-- Armory's stratagem/vehicle entity graph. Views share the editor's field objects
-- and canonical config owners; component rows are built only when expanded.
local D=require('demolition')
local V=require('component_view')
local Data=require('stratagem_entity_specs')
local M={}
local MAX=4294967295
local function type_hash(name)local h=5381;for i=1,#name do h=(h*33+name:byte(i))%4294967296 end;return(h-5381)%4294967296 end
local CATEGORIES={
 stratagem={0,{'Stratagem definition','战备定义','戰備定義'}},
 vehicle={1,{'Vehicle components','载具组件','載具組件'}},
 weapon={2,{'Weapon components','武器组件','武器組件'}},
 target={3,{'Targeting and guidance','瞄准与制导','瞄準與制導'}},
 protection={4,{'Health and protection','生命与防护','生命與防護'}},
 payload={5,{'Payloads and mounts','载荷与挂载','載荷與掛載'}},
 other={6,{'Other named components','其他已命名组件','其他已命名組件'}},
 unknown={100,{'Unnamed components','未命名组件','未命名組件'}},
}
local function category(name)
 if name=='VehicleComponentData'then return'vehicle'end
 if name:find('Weapon')then return'weapon'end
 if name:find('Sensor')or name:find('Target')or name:find('Turret')or name:find('Missile')then return'target'end
 if name:find('Health')or name:find('Shield')or name:find('Damage')or name:find('HitReact')or name:find('StatusEffect')or name:find('Drown')then return'protection'end
 if name:find('Hellpod')or name:find('Mount')or name:find('Deposit')or name:find('Inventory')or name:find('Equipment')or name:find('Interactable')or name:find('Package')then return'payload'end
 return'other'
end
function M.register(kinds)
 for _,root in ipairs(Data.ROOTS)do
  if not kinds[root[1]]then kinds[root[1]]={name='stratagem_entity_'..string.format('%08X',root[1]),stride=root[2],keyed=true}end
 end
end
local function raw_rows(page)
 local out={}
 if page.component_groups then
  for _,group in ipairs(page.component_groups)do for _,row in ipairs(group.rows)do out[#out+1]=row end end
 else for _,row in ipairs(page.rows)do out[#out+1]=row end end
 return out
end
-- Reflect inline fields with the installed type library. Descriptors and unsupported
-- widths are explicitly read-only; a pointer is never treated as an editable hash.
function M.reflect(root,schemas)
 local t=schemas[root[1]];local row=t and t.members[2]and schemas[t.members[2].type]
 if not row or row.size~=root[2]then return nil,'record size differs'end
 local key='ecs_'..string.format('%08X',root[1])
 local spec={TYPE=root[3],HASH=root[1],KEY=key,SIZE=row.size,SLOT='Stratagems',FLAG=key,
  COMPONENT={root[3],root[3],root[3]},GROUPS={{'fields','Component fields','组件字段','組件欄位'}},FIELDS={},STRICT=true}
 local descriptors,refs={},{}
 local function walk(typ,base,path,depth)
  assert(depth<32,'component struct nesting exceeds 32')
  for _,m in ipairs(schemas[typ].members)do
   local off=base+m.offset;local id=path..string.format('field_%04X',m.offset)
   if m.atom==1 or m.storage==10 or m.storage==11 then
    descriptors[#descriptors+1]={offset=off,size=m.size,id=id,array=m.atom==1,storage=m.storage,element_type=m.type}
   elseif m.atom==3 then
    local shift=math.floor(m.count/256);local width=m.count%256
    if width>0 and shift+width<=m.size*8 and(m.size==1 or m.size==2 or m.size==4)then
     local storage=width==1 and shift<8 and('bit'..shift)or('bits'..m.size..'_'..shift..'_'..width)
     spec.FIELDS[#spec.FIELDS+1]={id,off,storage,'fields',string.format('Field +0x%X bits %d:%d',off,shift,width),
      string.format('字段 +0x%X 位 %d:%d',off,shift,width),string.format('欄位 +0x%X 位 %d:%d',off,shift,width),{0,2^width-1,1,1},
      {id=id..'_bit'..shift}}
    else descriptors[#descriptors+1]={offset=off,size=m.size,id=id,storage=m.storage}end
   else
    local n=m.atom==2 and m.count or 1
    for i=0,n-1 do
     local at=off+(n>0 and i*m.size/n or 0);local name=id..(m.atom==2 and('_'..i)or'')
     if m.storage==20 and schemas[m.type]then walk(m.type,at,name..'_',depth+1)
     else
      local storage=({[0]='i8',[2]='i32',[4]='u8',[5]='u16',[6]='u32',[7]='u64',[8]='f32',[12]='enum',[14]='u8',[16]='enum',[17]='u64'})[m.storage]
      if storage then
       local r=storage=='f32'and{-1e12,1e12,.1,1,true}or storage=='i32'and{-2147483648,2147483647,1,10,true}
        or storage=='i8'and{-128,127,1,10,true}or{0,storage=='u8'and 255 or storage=='u16'and 65535 or MAX,1,10}
       spec.FIELDS[#spec.FIELDS+1]={name,at,storage,'fields',string.format('Field +0x%X (%s)',at,storage),
        string.format('字段 +0x%X（%s）',at,storage),string.format('欄位 +0x%X（%s）',at,storage),r,{id=name}}
       if m.storage==7 then refs[#refs+1]=at end
      else descriptors[#descriptors+1]={offset=at,size=m.size/math.max(n,1),id=name,storage=m.storage}end
     end
    end
   end
  end
 end
 walk(t.members[2].type,0,'',0)
 local function layout(typ)
  local out,nested,seen={},{},{}
  for _,m in ipairs(schemas[typ].members)do if not seen[m.offset]then
   seen[m.offset]=true;out[#out+1]={m.offset,m.size}
   if m.storage==20 and m.atom~=1 and schemas[m.type]then
    local l,n=layout(m.type);nested[m.offset]={size=schemas[m.type].size,required=true,layout=l,nested=n}
   end
  end end
  table.sort(out,function(a,b)return a[1]<b[1]end);return out,nested
 end
 spec.LAYOUT,spec.NESTED=layout(t.members[2].type)
 return V.prepare(spec),descriptors,refs
end
function M.attach(c)
 local schemas=c.schemas or{};local roots,by_kind,specs,reflect={},{},{},{}
 for _,s in ipairs(c.specs or{})do specs[s.HASH or type_hash(s.TYPE)]=s end
 for _,s in ipairs(Data.SPECS)do specs[s.HASH]=s end
 local entities,record_users={},{}
 for _,root in ipairs(Data.ROOTS)do
  local t=c.tables[root[1]];local schema=schemas[root[1]]
  if t and schema and schema.members[2]and schemas[schema.members[2].type]and schemas[schema.members[2].type].size==root[2]then
   roots[#roots+1]=root;by_kind[root[1]]=root
   record_users[root[1]]={}
   for k,offset in pairs(t.index)do if type(k)=='string'and #k==8 then
    entities[k]=true;record_users[root[1]][offset]=(record_users[root[1]][offset]or 0)+1
   end end
  end
 end
 local function reflected(root)
  if not reflect[root[1]]then reflect[root[1]]={M.reflect(root,schemas)}end
  return unpack(reflect[root[1]])
 end
 local sources,graph={},{}
 local change_stamp,changed_offsets
 local function changed_fields()
  local overrides=c.overrides and c.overrides()or{}
  local stamp=tostring(c.change_version and c.change_version())..':'..#overrides
  if changed_offsets and stamp==change_stamp then return changed_offsets end
  changed_offsets={};change_stamp=stamp
  for _,o in ipairs(overrides)do
   local page=c.by_hash[o.hash]
   for _,p in ipairs(page and c.parts and c.parts(page,o.id)or{})do
    local f=p.field;local original=c.default_of(f);local value=c.read(f)
    if f.kind and f.offset and value~=nil and original~=nil and math.abs(value-original)>1e-4 then
     changed_offsets[f.kind]=changed_offsets[f.kind]or{};changed_offsets[f.kind][f.offset]=true
    end
   end
  end
  return changed_offsets
 end
 local function links(key)
  if graph[key]then return graph[key]end
  local found={};graph[key]=found
  for _,root in ipairs(roots)do
   local t=c.tables[root[1]];local at=t.index[key]
   if at then
    local _,descriptors,refs=reflected(root)
    for _,off in ipairs(refs or{})do
     local bytes=c.bytes(root[1],at+off,8)
     if bytes and entities[bytes]and bytes~=key then found[bytes]=true end
    end
    -- Dynamic arrays remain read-only in the UI, but typed entity references in
    -- bounded in-table arrays still contribute their related component entities.
    if c.array_bytes then for _,d in ipairs(descriptors or{})do if d.array then
     local offsets={}
     local function reference_offsets(typ,base,depth)
      if depth>16 or not schemas[typ]then return end
      for _,m in ipairs(schemas[typ].members)do if m.atom==0 or m.atom==2 then
       local n=m.atom==2 and m.count or 1
       for i=0,n-1 do local at=base+m.offset+i*m.size/math.max(n,1)
        if m.storage==7 then offsets[#offsets+1]=at
        elseif m.storage==20 then reference_offsets(m.type,at,depth+1)end
       end
      end end
     end
     local stride
     if d.storage==7 then stride=8;offsets[1]=0
     elseif d.storage==20 and schemas[d.element_type]then stride=schemas[d.element_type].size;reference_offsets(d.element_type,0,0)end
     if stride and stride>0 and #offsets>0 then
      local bytes,count=c.array_bytes(root[1],at+d.offset,stride)
      for i=0,bytes and count-1 or-1 do for _,off in ipairs(offsets)do
       local target=bytes:sub(i*stride+off+1,i*stride+off+8)
       if entities[target]and target~=key then found[target]=true end
      end end
     end
    end end end
   end
  end
  return found
 end
 local function source(root,key,owner)
  local identity=root[1]..':'..key;local existing=sources[identity];if existing then return existing end
  local hex=D.hex(key);local view=c.views and c.views[root[1]]
  local page=view and view.by_entity and view.by_entity[hex]
  if not page then
   page={hash=D.hex(D.hash_resource('shodan/stratagem_entity/'..string.format('%08X',root[1])..'/'..hex:lower())),
    name=owner.name..' / '..hex,slot=owner.slot,key=key,rows={},by_id={},field_keys={},nav_hidden=true,stratagem_entity_source=true}
   c.by_hash[page.hash]=page;c.weapons[#c.weapons+1]=page
   page.ensure_rows=function()
    if page.rows_built then return end;page.rows_built=true
    local fallback,descriptors=reflected(root);local spec=specs[root[1]]or fallback
    if not V.check_layout(spec,schemas,root[1])then spec=fallback end
    local ctx={table={index={[key]=c.tables[root[1]].index[key]}},kind=root[1],weapons=c.weapons,by_hash=c.by_hash,
     field_at=c.field_at,read=c.read,add_row=c.add_row,default_of=c.default_of,schemas=schemas,names=c.names,lang=c.lang,
     reference=c.reference,page_for=function()return page end}
    V.build(spec,ctx)
    for _,d in ipairs(descriptors or{})do
     local row={id='descriptor_'..d.id,label=string.format('Field +0x%X',d.offset),parts={},empty=true,storage='u32',
      component=root[3],section='ecs:descriptors',section_of=function()return V.pick(c.lang(),{'Arrays and descriptors (read only)','数组与描述符（只读）','陣列與描述符（唯讀）'})end}
     row.label_of=function()return string.format(V.pick(c.lang(),{'Descriptor +0x%X','描述符 +0x%X','描述符 +0x%X'}),d.offset)end
     row.readonly_text=function()
      local bytes=c.bytes(root[1],c.tables[root[1]].index[key]+d.offset,d.size)
      if not bytes then return '?'end
      if d.array and #bytes>=12 then return tostring(D.u32(bytes,8))..V.pick(c.lang(),{' entries (read only)',' 项（只读）',' 項（唯讀）'})end
      return(bytes:gsub('.',function(ch)return string.format('%02X',ch:byte())end)):sub(1,64)
     end
     page.rows[#page.rows+1]=row
    end
   end
  end
  sources[identity]=page;return page
 end
 local originals={};local original_rows={};local original_hidden={}
 local entity_pages={Stratagems={},Mechas={}};local lists={Stratagems={},Mechas={}}
 local names={};for _,r in ipairs(c.entities or{})do names[r.hash]=r.base_name or r.name end
 for _,w in ipairs(c.weapons)do
  if not w.nav_hidden and not w.stratagem_entity_page and(c.tab_of(w)=='Stratagems'or c.tab_of(w)=='Mechas')then
   originals[#originals+1]=w;original_rows[w]=w.rows;original_hidden[w]=w.hidden_rows or{}
   local key=w.key or(w.stratagem and w.stratagem.vehicle)
   w.stratagem_entity_key=key and entities[key]and key or nil
   if w.stratagem_entity_key then
    local map=entity_pages[w.slot];if not map[key]or not w.stratagem then map[key]=w end
    names[D.hex(key)]=names[D.hex(key)]or w.name
   end
  end
 end
 local function entity_name(key)
  local hex=D.hex(key);return names[hex]or(c.names or{})[hex]or hex
 end
 local pages={};local all_seen={}
 local function related_page(key,owner)
  local tab=owner.slot;local map=entity_pages[tab]
  if not map[key]then
   local hex=D.hex(key)
   local page={hash=D.hex(D.hash_resource('shodan/stratagem_entity_page/'..tab..'/'..hex:lower())),
    name=entity_name(key),slot=tab,key=key,stratagem_entity_key=key,entity_hash=hex,
    stratagem_entity_page=true,rows={},by_id={},field_keys={}}
   map[key]=page;c.weapons[#c.weapons+1]=page;c.by_hash[page.hash]=page
   original_rows[page]={};original_hidden[page]={}
  end
  local page=map[key];page.entity_referrers=page.entity_referrers or{};page.entity_referrers[owner.hash]=owner
  return page
 end
 local function append(page,tab)
  if not all_seen[page]then all_seen[page]=true;pages[#pages+1]=page;lists[tab][#lists[tab]+1]=page end
 end
 for _,weapon in ipairs(originals)do
  local seeds,queue={},{}
  local function seed(key)if key and entities[key]and not seeds[key]then seeds[key]=true;queue[#queue+1]=key end end
  seed(weapon.stratagem_entity_key)
  local def=weapon.stratagem
  if def then
   for _,key in ipairs(def.payloads or{})do seed(key)end
   for _,key in ipairs(def.twins or{})do seed(key)end
   if def.drone then seed(def.drone.drone);seed(def.drone.gun)end
  end
  local at=1;while queue[at]do local key=queue[at];at=at+1;for target in pairs(links(key))do seed(target)end end
  table.sort(queue,function(a,b)return D.hex(a)<D.hex(b)end)
  weapon.related_entities=queue
  append(weapon,weapon.slot)
  for _,key in ipairs(queue)do append(related_page(key,weapon),weapon.slot)end
 end
 for _,weapon in ipairs(pages)do
  local old=original_rows[weapon]or{};local old_hidden=original_hidden[weapon]or{}
  local groups,matched={},{}
  local key=weapon.stratagem_entity_key
  local hex=key and D.hex(key)
  weapon.entity_hash=hex;weapon.field_keys={}
  weapon.note_of=function()
   if not key then return V.pick(c.lang(),{'Stratagem definition; payload entities are separate entries.','战备定义；载荷与关联实体分别列出。','戰備定義；載荷與關聯實體分別列出。'})end
   return V.pick(c.lang(),{'Entity ','实体 ','實體 '})..hex..V.pick(c.lang(),{' · Only this entity’s components; references are separate entities.',' · 仅显示本实体组件；关联引用另列实体。',' · 僅顯示本實體組件；關聯引用另列實體。'})
  end
  for _,root in ipairs(roots)do if key and c.tables[root[1]].index[key]then
   local raw=source(root,key,weapon);local kind=root[1];matched[kind]=true
   local hex=D.hex(key);local spec=specs[kind]
   local label=spec and spec.COMPONENT or{root[3],root[3],root[3]}
   if root[3]:match('^Component_0x')then label={root[3],'未命名组件（0x'..string.format('%08X',kind)..'）','未命名組件（0x'..string.format('%08X',kind)..'）'}end
   local bucket=root[3]:match('^Component_0x')and'unknown'or category(root[3])
   local fallback,descriptors=reflected(root)
   local shared=record_users[kind][c.tables[kind].index[key]]or 1
   local group={type=root[3]..':'..hex,label=label,rows={},count=spec and #spec.FIELDS or #fallback.FIELDS+#descriptors,
    field_kind=kind,field_offset=c.tables[kind].index[key],shared_count=shared,
    sub=bucket,sub_label=CATEGORIES[bucket][2],rank=CATEGORIES[bucket][1],entity=hex,
    label_of=function()return V.pick(c.lang(),label)..(shared>1 and(' · '..V.pick(c.lang(),{'Shared record: ','共用记录：','共用記錄：'})..shared)or'')end,hide_type=true}
   group.modified=function()
    if raw.ensure_rows and not raw.rows_built then
     local start=c.tables[kind].index[key]
     for offset in pairs(changed_fields()[kind]or{})do if offset>=start and offset<start+root[2]then return true end end
     return false
    end
    for _,row in ipairs(raw_rows(raw))do for _,part in ipairs(row.parts or{})do
     local v,d=c.read(part.field),c.default_of(part.field)
     if v~=nil and d~=nil and math.abs(v-d)>1e-4 then return true end
    end end
    return false
   end
   group.ensure_rows=function()
    if raw.ensure_rows then raw.ensure_rows()end
    local rows={}
    for _,original in ipairs(raw_rows(raw))do
     local row=setmetatable({parts={}}, {__index=original})
     for _,part in ipairs(original.parts or{})do
      local p={};for name,v in pairs(part)do p[name]=v end
      p.row=row;p.health_owner=part.health_owner or{weapon=raw,part=part};row.parts[#row.parts+1]=p
      weapon.by_id['ecs_'..string.format('%08X',kind)..'_'..hex..'_'..p.id]=p
      weapon.field_keys=weapon.field_keys or{};weapon.field_keys[p.field.key]=true
      if not weapon.by_id[p.id]then weapon.by_id[p.id]=p end
      local users=p.field.users;local known=false;for _,u in ipairs(users)do if u==weapon then known=true end end;if not known then users[#users+1]=weapon end
     end
     rows[#rows+1]=row
    end
    return rows
   end
   groups[#groups+1]=group
  end end
  local function own_row(row)
   if row.section and row.section:match('^StratagemType')then return true end
   if not key or #(row.parts or{})==0 then return false end
   for _,part in ipairs(row.parts)do
    local f=part.field
    if f.demolition then if not f.target or f.target.hash~=hex then return false end
    else
     local root=by_kind[f.kind];local offset=root and c.tables[f.kind].index[key]
     if not offset or not f.offset or f.offset<offset or f.offset>=offset+root[2]then return false end
    end
   end
   return true
  end
  local strat,demolition={},{}
  local hidden={}
  for _,row in ipairs(old)do
   if own_row(row)then
    hidden[#hidden+1]=row
    if row.section and row.section:match('^StratagemType')then strat[#strat+1]=row
    elseif row.parts[1]and row.parts[1].field.demolition then demolition[#demolition+1]=row end
   end
  end
  for _,row in ipairs(old_hidden)do if own_row(row)then hidden[#hidden+1]=row end end
  if key and c.archive_rows then
   local sections={}
   for _,row in ipairs(c.archive_rows(weapon,key))do
    hidden[#hidden+1]=row
    local section=row.section;sections[section]=sections[section]or{};sections[section][#sections[section]+1]=row
   end
   for section,rows in pairs(sections)do
    local labels={Handling={'Vehicle handling (physics)','载具操控（物理）','載具操控（物理）'},
     Wheels={'Wheels (physics)','车轮与悬挂（物理）','車輪與懸吊（物理）'},
     Movement={'Exosuit movement (shared state machine)','机甲移动（共用状态机）','機甲移動（共用狀態機）'}}
    groups[#groups+1]={type='ArchivePhysics:'..section..':'..hex,label=labels[section]or{section,section,section},
     rows=rows,rank=1.5,sub='vehicle',sub_label=CATEGORIES.vehicle[2],entity=hex,archive_physics=true,hide_type=true}
   end
  end
  if #strat>0 then groups[#groups+1]={type='StratagemType',label={'Stratagem component','战备组件','戰備組件'},rows=strat,rank=0,sub='stratagem',sub_label=CATEGORIES.stratagem[2]}end
  if #demolition>0 then groups[#groups+1]={type='DemolitionOverrides',label={'Demolition overrides','拆毁覆盖组件','拆毀覆寫組件'},rows=demolition,rank=4,sub='protection',sub_label=CATEGORIES.protection[2]}end
  -- These are references, not ownership. The same target may be referenced by
  -- multiple entities; cycles are shown as links rather than flattened children.
  local referenced={}
  if key then
   for target in pairs(links(key))do referenced[target]='out' end
   for from,targets in pairs(graph)do if targets[key]then referenced[from]=referenced[from]=='out'and'both'or referenced[from]or'in'end end
  end
  local def=weapon.stratagem
  for _,target in ipairs(def and def.payloads or{})do if entities[target]and target~=key then referenced[target]='payload'end end
  local relation_rows={};local targets={};for target in pairs(referenced)do if entity_pages[weapon.slot][target]then targets[#targets+1]=target end end
  table.sort(targets,function(a,b)return D.hex(a)<D.hex(b)end)
  for _,target in ipairs(targets)do
   local page=entity_pages[weapon.slot][target];local direction=referenced[target]
   local prefix=direction=='both'and{'Mutual reference: ','双向引用：','雙向引用：'}or direction=='in'and{'Referenced by: ','被引用：','被引用：'}or direction=='payload'and{'Payload reference: ','载荷引用：','載荷引用：'}or{'References: ','引用：','引用：'}
   relation_rows[#relation_rows+1]={id='entity_reference_'..D.hex(target),label=entity_name(target),parts={},storage='u32',entity_target=page,entity_direction=direction,
    section='entity_references',section_of=function()return V.pick(c.lang(),{'Entity references','实体引用关系','實體引用關係'})end,
    label_of=function()return V.pick(c.lang(),prefix)..(c.tr and c.tr(entity_name(target))or entity_name(target))end,
    tip={D.hex(target),V.pick(c.lang(),{'Reference does not imply parent/child ownership.','引用不表示父子或组件归属。','引用不表示父子或組件歸屬。'})},
    custom_text=function()return V.pick(c.lang(),{'View entity','查看实体','查看實體'})end,
    custom_action=function()return c.open_entity and c.open_entity(page)end}
  end
  if #relation_rows>0 then groups[#groups+1]={type='EntityReferences',label={'Entity references','实体引用关系','實體引用關係'},rows=relation_rows,
   rank=7,sub='relations',sub_label={'Entity references (not component ownership)','实体引用关系（不代表归属）','實體引用關係（不代表歸屬）'}}end
  table.sort(groups,function(a,b)if a.rank~=b.rank then return a.rank<b.rank end;return a.type<b.type end)
  weapon.hidden_rows=hidden;weapon.stratagem_entity_groups=true
  weapon.stratagem_prior_modified=weapon.stratagem_prior_modified or weapon.custom_modified
  weapon.custom_modified=function()
   for _,g in ipairs(groups)do if g.header and g.header.component_modified()then return true end end
   return false
  end
  weapon.rows={}
  c.wrap(weapon,groups,{'Stratagem components','战备相关组件','戰備相關組件'})
 end
 if c.log then c.log('armory stratagem entities: '..#pages..' pages; '..#roots..' current keyed component types')end
 return {pages=pages,sources=sources,roots=roots,graph=graph,lists=lists,entity_pages=entity_pages}
end
return M
