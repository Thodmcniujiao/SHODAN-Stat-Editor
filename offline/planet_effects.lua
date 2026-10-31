-- Portable, additive planet -> effect assignments. No native game-file writes.
local J=require('json_data')
local G=require('galactic_effects')
local DATA=require('planet_effect_data')
local M={data=DATA}
local function copy(v)return J.decode(J.encode(v))end
function M.new(c)
 c=c or{};local fs=c.fs or require('preset_files');local folder=c.folder or require('user_paths').home
 local self={path=folder..'/planet_effects.json',folder=folder,revision=0,planets={},catalog=G.index(G.data)}
 self.roles=select(2,G.index(G.data))
 for _,p in ipairs(DATA.planets)do self.planets[p.index]=p end
 self.cfg={version=1,war_id=DATA.war_id,enabled=false,selected_planet=-1,targets={},definitions={},icon_pairs={}}
 local raw=fs.read(self.path)
 if raw then
  local ok,v=pcall(J.decode,raw)
  local valid=ok and type(v)=='table'and v.version==1 and v.war_id==DATA.war_id and type(v.enabled)=='boolean'
    and type(v.targets)=='table'and v.targets~=J.null and not(getmetatable(v.targets)or{}).__json_array
    and type(v.definitions)=='table'and v.definitions~=J.null and type(v.icon_pairs)=='table'and v.icon_pairs~=J.null
    and type(v.selected_planet)=='number'and(v.selected_planet==-1 or self.planets[v.selected_planet]~=nil)
  if valid then for key,t in pairs(v.targets)do
   local id=type(key)=='string'and tonumber(key)
   if not id or tostring(id)~=key or not self.planets[id]or type(t)~='table'or type(t.include_icons)~='boolean'or type(t.effects)~='table'or t.effects==J.null then valid=false;break end
   local seen,count={},0
   for k,e in pairs(t.effects)do
    if type(k)~='number'or k%1~=0 or k<1 or k>#t.effects or type(e)~='number'or not self.catalog[e]or seen[e]then valid=false;break end
    seen[e]=true;count=count+1
   end
   if count~=#t.effects then valid=false end
   if t.replace~=nil and type(t.replace)~='boolean'then valid=false;break end
   if t.removed~=nil then
    if type(t.removed)~='table'or t.removed==J.null then valid=false;break end
    local rseen,rcount={},0
    for k,e in pairs(t.removed)do
     if type(k)~='number'or k%1~=0 or k<1 or k>#t.removed or type(e)~='number'or not self.catalog[e]or rseen[e]then valid=false;break end
     rseen[e]=true;rcount=rcount+1
    end
    if rcount~=#t.removed then valid=false;break end
   end
  end end
  if valid then self.cfg=v else self.error='Cannot read planet_effects.json; file preserved. Repair it before saving.'end
 end
 function self:mutate(fn)
  if self.error then return nil,self.error end
  local previous=copy(self.cfg);fn()
  local ok,why=(c.mkdir or fs.mkdir)(folder)
  if ok then ok,why=fs.write(self.path..'.tmp',J.encode(self.cfg,true))end
  if ok then ok,why=fs.move(self.path..'.tmp',self.path)end
  if not ok then self.cfg=previous;fs.remove(self.path..'.tmp');return nil,why or'Cannot save planet effects'end
  self.revision=self.revision+1;return true
 end
 function self:select(planet)
  if not self.planets[planet]then return nil,'Planet is not in the current WarInfo catalogue'end
  if self.cfg.selected_planet==planet then return true end
  return self:mutate(function()self.cfg.selected_planet=planet end)
 end
 function self:target(planet)return self.cfg.targets[tostring(planet)]or{effects=J.array(),include_icons=true}end
 local function keep_target(t)
  if t.removed and #t.removed==0 then t.removed=nil end
  if not t.replace then t.replace=nil end
  return (#t.effects>0 or(t.removed and #t.removed>0)or t.replace==true)and t or nil
 end
 function self:changed(planet)
  local t=self:target(planet)
  return #t.effects>0 or(t.removed and #t.removed>0)or t.replace==true
 end
 function self:replace_mode(planet)return self:target(planet).replace==true end
 function self:set_replace(planet,on)
  if not self.planets[planet]or type(on)~='boolean'then return nil,'Invalid replace option'end
  return self:mutate(function()
   local t=self:target(planet);t.replace=on or nil
   self.cfg.targets[tostring(planet)]=keep_target(t)
  end)
 end
 function self:is_removed(planet,id)
  local t=self:target(planet)
  for _,r in ipairs(t.removed or{})do if r==id then return true end end
  return false
 end
 function self:toggle_removed(planet,id)
  if not self.planets[planet]or type(id)~='number'or not self.catalog[id]then return nil,'Unknown effect ID'end
  return self:mutate(function()
   local t=self:target(planet)
   t.removed=t.removed and J.array(t.removed)or J.array()
   local found=false
   for i=#t.removed,1,-1 do if t.removed[i]==id then table.remove(t.removed,i);found=true end end
   if not found then t.removed[#t.removed+1]=id;self:remember(id);table.sort(t.removed)end
   self.cfg.targets[tostring(planet)]=keep_target(t)
  end)
 end
 function self:effective(planet)
  local t=self:target(planet);local out,seen={},{}
  local function add(id)if not seen[id]then seen[id]=true;out[#out+1]=id end end
  for _,id in ipairs(t.effects)do
   add(id);local pair=self.roles[id]
   if t.include_icons and pair and pair.kind=='effect'then add(pair.other)end
  end
  table.sort(out);return out
 end
 function self:live()
  local now=os.time()
  if self.live_at~=now then
   self.live_at=now;self.last_live=nil
   local raw=fs.read(folder..'/WarProxy/live_planet_effects.json')
   if raw then local ok,v=pcall(J.decode,raw);if ok and type(v)=='table'and type(v.planets)=='table'then self.last_live=v end end
  end
  return self.last_live
 end
 function self:live_on(planet)
  local l=self:live()
  local list=l and l.planets and l.planets[tostring(planet)]
  return type(list)=='table'and list or{}
 end
 function self:effective_with_live(planet)
  local t=self:target(planet)
  local blocked={}
  for _,r in ipairs(t.removed or{})do
   blocked[r]=true
   local pair=self.roles[r]
   if t.include_icons and pair and pair.kind=='effect'then blocked[pair.other]=true end
  end
  local out,seen={},{}
  local function add(id)if not seen[id]then seen[id]=true;out[#out+1]=id end end
  if not t.replace then
   for _,id in ipairs(self:live_on(planet))do if not blocked[id]then add(id)end end
  end
  for _,id in ipairs(self:effective(planet))do add(id)end
  table.sort(out);return out
 end
 function self:remember(id)
  local b=self.catalog[id].definition
  self.cfg.definitions[tostring(id)]={effectType=b.effectType,nameHash=b.nameHash}
  local pair=self.roles[id]
  if pair and pair.kind=='effect'then self.cfg.icon_pairs[tostring(id)]=pair.other;self:remember(pair.other)end
 end
 function self:add(planet,ids)
  if not self.planets[planet]then return nil,'Unknown planet index'end
  if type(ids)=='number'then ids={ids}end
  if type(ids)~='table'or #ids==0 then return nil,'Choose an existing effect ID'end
  for _,id in ipairs(ids)do if type(id)~='number'or not self.catalog[id]then return nil,'Unknown effect ID: '..tostring(id)end end
  return self:mutate(function()
   local t=self:target(planet);self.cfg.targets[tostring(planet)]=t
   local seen={};for _,id in ipairs(t.effects)do seen[id]=true end
   for _,id in ipairs(ids)do if not seen[id]then t.effects[#t.effects+1]=id;seen[id]=true end;self:remember(id)end
   table.sort(t.effects);self.cfg.selected_planet=planet
  end)
 end
 function self:remove(planet,id)
  return self:mutate(function()
   local t=self:target(planet)
   for n=#t.effects,1,-1 do if t.effects[n]==id then table.remove(t.effects,n)end end
   self.cfg.targets[tostring(planet)]=keep_target(t)
  end)
 end
 function self:icons(planet,on)
  if not self.planets[planet]or type(on)~='boolean'then return nil,'Invalid icon option'end
  return self:mutate(function()local t=self:target(planet);t.include_icons=on;self.cfg.targets[tostring(planet)]=t end)
 end
 function self:reset(planet)
  return self:mutate(function()self.cfg.targets[tostring(planet)]=nil end)
 end
 function self:master(on)
  if type(on)~='boolean'then return nil,'Expected boolean'end
  return self:mutate(function()self.cfg.enabled=on end)
 end
 function self:reload()
  local fresh=M.new(c)
  if fresh.error then self.error=fresh.error;return nil,fresh.error end
  self.cfg,self.error=fresh.cfg,nil;self.revision=self.revision+1;return true
 end
 function self:status()
  local now=os.time()
  if self.status_at~=now then
   self.status_at=now;self.last_status=nil
   local raw=fs.read(folder..'/WarProxy/planet_effect_status.json')
   if raw then local ok,v=pcall(J.decode,raw);if ok and type(v)=='table'and type(v.message)=='string'then self.last_status=v end end
  end
  return self.last_status
 end
 return self
end
return M
