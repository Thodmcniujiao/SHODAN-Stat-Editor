-- Attach component headers now, materialize their shared rows only on use.
local M={}
local Work=require('startup_work')
local function saved_ids(spec)
 if spec.saved_field_ids then return spec.saved_field_ids end
 local ids={}
 for _,field in ipairs(spec.FIELDS)do
  local id=field[9]and field[9].id or field[1];ids[id]=true
  if field[3]=='u64'then ids[id..'_lo'],ids[id..'_hi']=true,true end
 end
 spec.saved_field_ids=ids;return ids
end
function M.attach(c)
 for _,weapon in ipairs(c.weapons)do if c.slots[weapon.slot]then
  Work.checkpoint()
  weapon.legacy_rows=weapon.legacy_rows or weapon.rows
  local groups,matched,all,hidden,lookup_order={},{},{},{},{}
  for _,row in ipairs(weapon.legacy_rows)do hidden[#hidden+1]=row end
  weapon.field_keys=weapon.field_keys or{}
  local function collect(list)
   for _,entry in ipairs(list)do
    local page=entry.view and entry.view.by_entity[weapon.hash]
    if page and(page.ensure_rows or #page.rows>0)then
     local spec=entry.spec;local sub=entry.sub or spec.SUB or'weapon'
     local info=c.subs[sub]or c.subs.weapon
     local group={type=spec.TYPE,label=spec.COMPONENT,hide_type=true,spec=spec,sub=sub,sub_label=info.name,
      rows={},raw_rows={},count=#spec.FIELDS,page=page,ids=saved_ids(spec)}
     group.modified=function()return c.changed(page)end
     group.ensure_rows=function()
      if page.ensure_rows then page.ensure_rows()end
      group.raw_rows=page.rows
      for _,row in ipairs(page.rows)do
       all[#all+1]=row;hidden[#hidden+1]=row
       for _,part in ipairs(row.parts)do
        weapon.field_keys[part.field.key]=true
        if not part.health_owner then part.health_owner={weapon=page,part=part}end
        local seen=false;for _,user in ipairs(part.field.users)do if user==weapon then seen=true;break end end
        if not seen then part.field.users[#part.field.users+1]=weapon end
        weapon.by_id[(page.component_view or spec.KEY)..'_'..part.id]=part
       end
      end
      return page.rows
     end
     groups[#groups+1]=group;lookup_order[#lookup_order+1]=group;matched[#matched+1]=spec
    end
   end
  end
  collect(c.primary);if #groups==0 then collect(c.fallback)end
  if #groups>0 then
   table.sort(groups,function(a,b)return(c.subs[a.sub]or c.subs.weapon).order<(c.subs[b.sub]or c.subs.weapon).order end)
   weapon.hidden_rows,weapon.all_component_rows,weapon.matched_components=hidden,all,matched
   c.wrap(weapon,groups,{'Components','组件','組件'})
   -- Saved IDs (including old prefixed aliases) can be restored before a group is opened.
   local previous=getmetatable(weapon.by_id);local meta={}
   for key,value in pairs(previous or{})do meta[key]=value end
   local inherited=not meta.lazy_components and meta.__index
   meta.lazy_components=true
   meta.__index=function(t,id)
    if type(id)=='string'then
     -- Keep the old collect order for ambiguous unprefixed IDs, independent of
     -- display sorting and which group the user happened to open first.
     for _,group in ipairs(lookup_order)do
      local prefix=(group.page.component_view or group.spec.KEY)..'_'
      local raw=id:sub(1,#prefix)==prefix and id:sub(#prefix+1)or id
      if group.ids[raw]then
       group.load();local part=rawget(t,id)or group.page.by_id[raw]
       if part then t[id]=part;return part end
      end
     end
    end
    if type(inherited)=='function'then return inherited(t,id)end
    return type(inherited)=='table'and inherited[id]or nil
   end
   setmetatable(weapon.by_id,meta)
   if not weapon.lazy_components_attached then weapon.component_previous_modified=weapon.custom_modified end
   local previous_modified=weapon.component_previous_modified
   weapon.lazy_components_attached=true
   weapon.custom_modified=function()
    if previous_modified and previous_modified()then return true end
    for _,group in ipairs(groups)do if group.modified()then return true end end
    return false
   end
   weapon.note=weapon.hash
   weapon.note_of=function()
    local lang=c.lang();local zh=lang=='zh-Hans'or lang=='zh-Hant'
    local names={};for _,spec in ipairs(matched)do names[#names+1]=zh and c.text(spec.COMPONENT):gsub('（.*$','')or spec.TYPE end
    if zh then return weapon.hash..(lang=='zh-Hant'and' · 匹配組件（'or' · 匹配组件（')..#matched..'）：'..table.concat(names,'、')end
    return weapon.hash..' · Matched components ('..#matched..'): '..table.concat(names,', ')
   end
  end
 end end
end
return M
