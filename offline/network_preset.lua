-- Portable network plans only. Certificates, proxy processes, Steam integration
-- and machine paths never belong to a preset. Imports stage with masters off.
local J=require('json_data');local G=require('galactic_effects')
local M={}
local function copy(v)return J.decode(J.encode(v))end
local function object(v)return type(v)=='table'and v~=J.null and not(getmetatable(v)or{}).__json_array end
local function uint(v)return type(v)=='number'and v%1==0 and v>=0 and v<=4294967295 end
local function portable(kind,source)
 local cfg={version=1,enabled=source.enabled}
 if kind=='assignments'then
  cfg.war_id=source.war_id;cfg.selected_planet=source.selected_planet
  cfg.targets={};cfg.definitions={};cfg.icon_pairs=copy(source.icon_pairs)
  for id,t in pairs(source.targets)do cfg.targets[id]={effects=copy(t.effects),include_icons=t.include_icons}end
  for id,b in pairs(source.definitions)do cfg.definitions[id]={effectType=b.effectType,nameHash=b.nameHash}end
 else
  cfg.effects={}
  for id,e in pairs(source.effects)do
   local base={id=e.base.id};for _,key in ipairs(G.fields)do base[key]=copy(e.base[key])end
   local changes={};for key,value in pairs(e.changes)do if G.valid(key,value)then changes[key]=copy(value)end end
   cfg.effects[id]={base=base,enabled=e.enabled,changes=changes}
  end
 end
 return cfg
end
function M.models()
 local p=package.loaded.planet_effect_view;local g=package.loaded.galactic_effect_view
 return {assignments=rawget(_G,'SHODAN_PLANET_EFFECT_MODEL')or p and p.model,
  definitions=rawget(_G,'SHODAN_GALACTIC_EFFECT_MODEL')or g and g.model}
end
function M.capture(models)
 models=models or M.models();local out={version=1}
 for kind,model in pairs(models)do if model then
  out[kind]=portable(kind,model.cfg)
 end end
 return out
end
function M.validate(snapshot,models)
 models=models or M.models()
 local ok,result=pcall(function()
  assert(object(snapshot)and snapshot.version==1,'Unsupported network preset')
  local out={version=1}
  for _,kind in ipairs({'assignments','definitions'})do local cfg=snapshot[kind]
   if cfg then
    local model=assert(models[kind],'Network editor unavailable: '..kind)
    assert(not model.error,model.error)
    assert(object(cfg)and cfg.version==1 and type(cfg.enabled)=='boolean','Invalid network configuration')
    if kind=='assignments'then
     assert(cfg.war_id==model.cfg.war_id,'Network preset belongs to another Galactic War')
     assert(cfg.selected_planet==-1 or uint(cfg.selected_planet)and model.planets[cfg.selected_planet],'Unknown selected planet')
     assert(object(cfg.targets)and object(cfg.definitions)and object(cfg.icon_pairs),'Invalid planet assignment maps')
     for key,target in pairs(cfg.targets)do
      local id=tonumber(key)
      assert(type(key)=='string'and tostring(id)==key and model.planets[id]and object(target),'Unknown planet assignment')
      assert(type(target.include_icons)=='boolean'and type(target.effects)=='table'and target.effects~=J.null,'Invalid effect list')
      local seen,count={},0
      for k,effect in pairs(target.effects)do
       assert(type(k)=='number'and k%1==0 and k>=1 and k<=#target.effects and model.catalog[effect]and not seen[effect],'Unknown or duplicate effect')
       seen[effect]=true;count=count+1
       local base=cfg.definitions[tostring(effect)]
       assert(base and base.effectType==model.catalog[effect].definition.effectType and base.nameHash==model.catalog[effect].definition.nameHash,'Effect definition changed; review the plan')
      end
      assert(count==#target.effects,'Sparse effect list')
     end
     for key,value in pairs(cfg.icon_pairs)do
      local pair=model.roles[tonumber(key)]
      assert(pair and pair.kind=='effect'and pair.other==value,'Effect/icon pairing changed')
     end
    else
     assert(object(cfg.effects),'Invalid definition map')
     for key,entry in pairs(cfg.effects)do
      local id=tonumber(key)
      assert(type(key)=='string'and uint(id)and tostring(id)==key and object(entry)and type(entry.enabled)=='boolean','Invalid definition entry')
      assert(object(entry.base)and entry.base.id==id and object(entry.changes),'Missing definition baseline')
      for _,field in ipairs(G.fields)do assert(G.valid(field,entry.base[field]),'Invalid definition baseline')end
      for field,value in pairs(entry.changes)do assert(G.valid(field,value),'Invalid definition field: '..tostring(field))end
     end
    end
    out[kind]=portable(kind,cfg)
   end
  end
  return out
 end)
 return ok and result or nil,not ok and tostring(result)or nil
end
local function merged(kind,current,incoming)
 local cfg=copy(current)
 if kind=='assignments'then
  cfg.selected_planet=incoming.selected_planet
  for key,target in pairs(incoming.targets)do
   local t=cfg.targets[key]or{effects=J.array(),include_icons=target.include_icons};local seen={}
   for _,id in ipairs(t.effects)do seen[id]=true end
   for _,id in ipairs(target.effects)do if not seen[id]then t.effects[#t.effects+1]=id;seen[id]=true end end
   table.sort(t.effects);t.include_icons=target.include_icons;cfg.targets[key]=t
  end
  for _,map in ipairs({'definitions','icon_pairs'})do for k,v in pairs(incoming[map])do cfg[map][k]=copy(v)end end
 else
  for key,entry in pairs(incoming.effects)do
   local old=cfg.effects[key]
   if old and J.encode(old.base)==J.encode(entry.base)then
    for k,v in pairs(entry.changes)do old.changes[k]=copy(v)end;old.enabled=entry.enabled
   else cfg.effects[key]=copy(entry)end
  end
 end
 return cfg
end
function M.apply(snapshot,models,o)
 models=models or M.models();o=o or{}
 local data,why=M.validate(snapshot,models);if not data then return nil,why end
 local done={}
 local function write(kind,cfg)
  local model=models[kind]
  if J.encode(model.cfg)==J.encode(cfg)then return true end
  return model:mutate(function()model.cfg=copy(cfg)end)
 end
 for _,kind in ipairs({'assignments','definitions'})do if data[kind]then
  local model=models[kind];local before=copy(model.cfg)
  local cfg=o.merge and merged(kind,before,data[kind])or data[kind]
  if not o.rollback then cfg.enabled=false end
  local ok,note=write(kind,cfg)
  if not ok then
   local failures={}
   for i=#done,1,-1 do local v=done[i];local restored,err=write(v.kind,v.before);if not restored then failures[#failures+1]=tostring(err)end end
   return nil,tostring(note)..(#failures>0 and('; network rollback failed: '..table.concat(failures,'; '))or'')
  end
  done[#done+1]={kind=kind,before=before}
  if kind=='definitions'then
   model.stale={}
   for id,entry in pairs(model.cfg.effects)do
    local known=model.catalog[tonumber(id)]
    if not known or J.encode(entry.base)~=J.encode(known.definition)then model.stale[id]=true end
   end
  end
 end end
 return true
end
return M
