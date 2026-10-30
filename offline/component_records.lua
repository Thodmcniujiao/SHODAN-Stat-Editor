-- A component's serialized data-array index is distinct from its EntityHash and StratagemTypeID.
-- Enumerate every record (including rows with no hash-map entry), one page per index.
local M={}
function M.new(context)
 local self={lists={},pages={}}
 function self:build(spec)
  local t,layout=spec.table,spec.table.records_layout
  local keys,owners={},{ }
  for key,offset in pairs(t.index)do
   local id=(offset-layout.data_offset)/layout.stride
   assert(id==math.floor(id)and id>=0 and id<layout.record_count,'component index outside data array')
   keys[id]=keys[id]or{};keys[id][#keys[id]+1]=key
  end
  for _,list in pairs(keys)do table.sort(list)end
  -- Existing pages supply names and canonical field/config owners, never list membership.
  local sources={};for _,page in ipairs(context.weapons)do if not page.component_index then sources[#sources+1]=page end end
  for _,page in ipairs(sources)do
   local score=page.stratagem and 3 or page.component_view and 2 or 1
   local groups=page.component_groups
   if not groups then
    local own,strat={},{}
    for _,row in ipairs(page.rows)do
     if page.stratagem and row.section and row.section:match('^StratagemType')then strat[#strat+1]=row
     else own[#own+1]=row end
    end
    groups={}
    if #strat>0 then groups[#groups+1]={type='StratagemType',label={'Stratagem component','战备组件','戰備組件'},rows=strat}end
    groups[#groups+1]={type=spec.component,label=spec.label,rows=own}
   end
   for _,g in ipairs(groups)do for _,row in ipairs(g.rows)do for _,p in ipairs(row.parts or{})do
    local f=p.field
    if f and f.kind==spec.kind then
     local id=math.floor((f.offset-layout.data_offset)/layout.stride)
     if id>=0 and id<layout.record_count and(not owners[id]or score>owners[id].score)then
      owners[id]={page=page,groups=groups,score=score}
     end
    end
   end end end
  end
  local list={};self.lists[spec.tab]=list
  for id=0,layout.record_count-1 do
   local owner=owners[id];local source=owner and owner.page
   local offset=layout.data_offset+id*layout.stride
   local page={hash=string.format('%s%014X',spec.prefix,id),slot='Stratagems',catalog_tab=spec.tab,
    component_type=spec.type,component_index=id,component_offset=offset,component_keys=keys[id]or{},
    name=source and source.name or spec.component,rows={},by_id={},field_keys={}}
   page.note=spec.component..' · ComponentIndexData.index '..id
   page.component_search=source and(source.name..' '..(source.note or''))or''
   local groups={}
   if owner then
    local mapped={}
    for _,g in ipairs(owner.groups)do
     local rows={}
     for _,old in ipairs(g.rows)do
      local row=setmetatable({parts={}}, {__index=old})
      for _,original in ipairs(old.parts or{})do
       local part={};for k,v in pairs(original)do part[k]=v end
       part.row=row;part.health_owner=original.health_owner or{weapon=source,part=original}
       row.parts[#row.parts+1]=part;page.by_id[part.id]=part;mapped[part.field]=part
       local users=part.field and part.field.users
       if users then users[#users+1]=page end
      end
      rows[#rows+1]=row
     end
     groups[#groups+1]={type=g.type,label=g.label,rows=rows}
    end
    for alias,part in pairs(source.by_id)do
     if mapped[part.field]then page.by_id[alias]=page.by_id[alias]or mapped[part.field]end
    end
   else
    spec.make_rows(page,offset,page.component_keys[1])
    groups[1]={type=spec.component,label=spec.label,rows=page.rows}
   end
   local main
   for _,g in ipairs(groups)do if g.type==spec.component then main=g;break end end
   main=main or groups[1]
   table.insert(main.rows,1,{id='component_record_index',parts={},storage='u32',empty=true,
    readonly_text=tostring(id),label='ComponentIndexData.index',section=spec.component..':identity',section_level='group',
    section_of=function()return 'ComponentIndexData.index'end,
    tip={'ComponentIndexData.index','Zero-based index in this component data array; not StratagemTypeID or EntityHash.'}})
   -- A hashless row must not inherit the component view's temporary zero-hash title.
   page.note=spec.component..' · ComponentIndexData.index '..id;page.note_of=nil
   if #page.component_keys==0 then page.entity_hash=nil;page.key=nil end
   context.wrap(page,groups,spec.sub)
   self.pages[page.hash]=page;context.by_hash[page.hash]=page
   context.weapons[#context.weapons+1]=page;list[#list+1]=page
  end
  return list
 end
 return self
end
return M
