-- Merge selected contents of one global preset into another. Pure data: the caller
-- previews the plan (additions, conflicts, blocked items) before replacing the target.
-- A ref names one item of a preset payload, as preset_details.lua attaches it to its rows:
--   {store='values',hash=,ids={...}}            parameter values (a 64-bit pair: both ids)
--   {store='game',key='armor_passives'|'stacks'|'own_off'|'quick_switches',id=}
--   {store='demolition',bucket='values'|'stale',id=,key=}
--   {store='loadout',key=}
--   {store='preload',bucket='selected'|'targets'|'edits'|'arrays'|'merge_enabled',hash=|key=}
--   {store='network',kind='assignments'|'definitions',field='enabled'|planet=|effect=}
--   {store='legacy'}                            an imported old preload plan: never merged
local J=require('json_data')
local M={}
local function copy(v)if v==nil then return nil end;return J.decode(J.encode(v),32*1024*1024)end
local function same(a,b)if a==nil or b==nil then return a==b end;return J.encode(a)==J.encode(b)end
function M.key(ref)
 if not ref then return nil end
 local s=ref.store
 if s=='values'then return'values:'..ref.hash..':'..table.concat(ref.ids,'+')end
 if s=='game'then return'game:'..ref.key..':'..tostring(ref.id)end
 if s=='demolition'then return'demolition:'..tostring(ref.id)..':'..tostring(ref.key)end
 if s=='loadout'then return'loadout:'..tostring(ref.key)end
 if s=='preload'then return'preload:'..ref.bucket..':'..tostring(ref.hash or ref.key or'')end
 if s=='network'then return'network:'..ref.kind..':'..(ref.field and('field:'..ref.field)or ref.planet and('planet:'..tostring(ref.planet))or('effect:'..tostring(ref.effect)))end
 return s
end
local function section(p,name)
 local d=p.data or{}
 if p.scope==name then return d end
 return d[name]
end
-- the item a ref names in a payload; nil: absent. Demolition looks in both buckets.
function M.get(p,ref)
 local s=ref.store
 if s=='values'then
  local out,any={},false
  for _,v in ipairs(p.values or{})do if v.hash==ref.hash then
   for _,id in ipairs(ref.ids)do if v.id==id then out[id]=v.value;any=true end end
  end end
  return any and out or nil
 elseif s=='game'then local g=section(p,'game');return g and g[ref.key]and g[ref.key][ref.id]
 elseif s=='demolition'then
  local d=(p.data or{}).demolition;if not d then return nil end
  for _,bucket in ipairs({ref.bucket,ref.bucket=='values'and'stale'or'values'})do
   local slots=d[bucket]and d[bucket][ref.id]
   if slots and slots[ref.key]~=nil then return slots[ref.key]end
  end
 elseif s=='loadout'then local l=section(p,'loadout');return l and l.values and l.values[ref.key]
 elseif s=='preload'then
  local pr=section(p,'preload');if not pr then return nil end
  if ref.bucket=='merge_enabled'then return pr.merge_enabled end
  return pr[ref.bucket]and pr[ref.bucket][ref.hash or ref.key]
 elseif s=='network'then
  local cfg=(p.data or{}).network;cfg=cfg and cfg[ref.kind];if not cfg then return nil end
  if ref.field then return cfg[ref.field]end
  if ref.planet then return cfg.targets and cfg.targets[ref.planet]end
  return cfg.effects and cfg.effects[ref.effect]
 end
end
-- writes the source's item into the target payload (copied); nil,why when it cannot be merged
local function put(target,source,ref,value)
 local s=ref.store
 if s=='legacy'then return nil,'imported old preload plans cannot be merged'end
 if target.scope~='global'then return nil,'target is not a global preset'end
 target.data=target.data or{version=3}
 local d=target.data
 if s=='values'then
  local kept={};for _,v in ipairs(target.values)do
   local hit=false;if v.hash==ref.hash then for _,id in ipairs(ref.ids)do if v.id==id then hit=true end end end
   if not hit then kept[#kept+1]=v end
  end
  for _,id in ipairs(ref.ids)do if value[id]~=nil then kept[#kept+1]={hash=ref.hash,id=id,value=value[id]}end end
  target.values=kept
  require('quick_modifications').merge_restore(target,source,ref)
 elseif s=='game'then
  d.game=d.game or{}
  for _,k in ipairs({'stacks','own_off','armor_passives','quick_switches'})do d.game[k]=d.game[k]or{}end
  d.game[ref.key][ref.id]=copy(value)
 elseif s=='demolition'then
  d.demolition=d.demolition or{values={},stale={}}
  for _,bucket in ipairs({'values','stale'})do
   d.demolition[bucket]=d.demolition[bucket]or{}
   local slots=d.demolition[bucket][ref.id]
   if slots then slots[ref.key]=nil;if next(slots)==nil then d.demolition[bucket][ref.id]=nil end end
  end
  local slots=d.demolition[ref.bucket][ref.id]or{};slots[ref.key]=value;d.demolition[ref.bucket][ref.id]=slots
 elseif s=='loadout'then
  local from=section(source,'loadout')
  if not d.loadout then d.loadout=copy(from);d.loadout.values={};d.loadout.baseline=from.baseline and{}or nil
  elseif d.loadout.version~=from.version then return nil,'equipment from another save format'end
  d.loadout.values=d.loadout.values or{}
  d.loadout.values[ref.key]=copy(value)
  if from.baseline and from.baseline[ref.key]~=nil then d.loadout.baseline=d.loadout.baseline or{};d.loadout.baseline[ref.key]=copy(from.baseline[ref.key])end
 elseif s=='preload'then
  d.preload=d.preload or{version=1,edits={},selected={},targets={},arrays={},merge_enabled=true}
  if ref.bucket=='merge_enabled'then d.preload.merge_enabled=value
  else d.preload[ref.bucket]=d.preload[ref.bucket]or{};d.preload[ref.bucket][ref.hash or ref.key]=copy(value)end
 elseif s=='network'then
  local src=source.data.network[ref.kind]
  d.network=d.network or{version=1}
  local cfg=d.network[ref.kind]
  if not cfg then
   if ref.kind=='assignments'then
    cfg={version=1,enabled=false,war_id=src.war_id,selected_planet=-1,targets={},definitions={},icon_pairs={}}
   else cfg={version=1,enabled=false,effects={}}end
   d.network[ref.kind]=cfg
  end
  if ref.kind=='assignments'and cfg.war_id~=src.war_id then return nil,'planet plan from another Galactic War'end
  if ref.field then cfg[ref.field]=value
  elseif ref.planet then
   cfg.targets[ref.planet]=copy(value)
   for _,effect in ipairs(value.effects or{})do
    local id=tostring(effect)
    if src.definitions and src.definitions[id]then cfg.definitions[id]=copy(src.definitions[id])end
    if src.icon_pairs and src.icon_pairs[id]~=nil then cfg.icon_pairs[id]=copy(src.icon_pairs[id])end
   end
  else cfg.effects[ref.effect]=copy(value)end
 else return nil,'unknown preset section'end
 return true
end
-- refs: the selected rows' refs (duplicates allowed). o.keep_target: conflicts keep the target's value.
-- o.target_unchanged(key): the target's item there equals the game's own value (overwriting it is no conflict).
function M.plan(source,target,refs,o)
 o=o or{}
 local result={payload={scope=target.scope,kind=target.kind,values=copy(target.values or{}),data=copy(target.data)},
  added={},conflicts={},kept={},same={},blocked={},missing={}}
 local seen={}
 for _,ref in ipairs(refs)do
  local key=M.key(ref)
  if key and not seen[key]then
   seen[key]=true
   if ref.store=='legacy'then result.blocked[#result.blocked+1]={key=key,ref=ref,why='imported old preload plans cannot be merged'}
   else
    local sv=M.get(source,ref)
    if sv==nil then result.missing[#result.missing+1]={key=key,ref=ref}
    else
     local tv=M.get(result.payload,ref)
     local list
     if tv~=nil and same(sv,tv)then list=result.same
     elseif tv~=nil and not(o.target_unchanged and o.target_unchanged(key))then list=o.keep_target and result.kept or result.conflicts
     else list=result.added end
     local entry={key=key,ref=ref,source=sv,target=tv}
     if list==result.added or list==result.conflicts then
      local ok,why=put(result.payload,source,ref,sv)
      if not ok then list=result.blocked;entry.why=why end
     end
     list[#list+1]=entry
    end
   end
  end
 end
 result.changes=#result.added+#result.conflicts
 return result
end
return M
