-- Wire definitions and portable authoring, separate from native game-file edits.
-- IDs are GalacticWarEffects IDs, not type-indexes, entity hashes or icons.
local J=require('json_data')
local M={data=require('galactic_effect_data')}
M.fields={'gameplayEffectId32','effectType','flags','nameHash','descriptionFluffHash',
 'descriptionGamePlayLongHash','descriptionGamePlayShortHash','valueTypes','values'}
local allowed={};for _,key in ipairs(M.fields)do allowed[key]=true end
local function copy(v)return J.decode(J.encode(v))end
local function same(a,b)return J.encode(a)==J.encode(b)end
function M.valid(key,value)
 if not allowed[key]then return false end
 if key=='values'or key=='valueTypes'then
  if type(value)~='table'or value==J.null or #value>16 then return false end
  local n=0;for k,v in pairs(value)do
   n=n+1
   if type(k)~='number'or k%1~=0 or k<1 or k>#value or type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return false end
   if key=='valueTypes'and(v%1~=0 or v<0 or v>4294967295)then return false end
  end
  return n==#value and(n>0 or(getmetatable(value)or{}).__json_array==true)
 end
 return type(value)=='number'and value%1==0 and value>=0 and value<=4294967295
end
function M.index(data)
 local by_id,roles={},{}
 for _,entry in ipairs(data.effects)do
  local id=entry.definition.id;assert(not by_id[id],'duplicate effect ID');by_id[id]=entry
 end
 for _,pair in ipairs(data.pairs or{})do
  local a,b=by_id[pair[1]],by_id[pair[2]]
  if a and b and a.definition.effectType==40 and b.definition.effectType==71 then
   roles[pair[1]]={kind='effect',other=pair[2]};roles[pair[2]]={kind='icon',other=pair[1]}
  end
 end
 return by_id,roles
end
function M.new(c)
 c=c or{};local fs=c.fs or require('preset_files')
 local folder=c.folder or require('user_paths').home
 local self={path=folder..'/galactic_effect_overrides.json',cfg={version=1,enabled=false,effects={}},stale={},revision=0}
 self.catalog,self.roles=M.index(c.data or M.data)
 local raw=fs.read(self.path)
 if raw then
  local ok,v=pcall(J.decode,raw)
  if not ok or type(v)~='table'or v.version~=1 or type(v.enabled)~='boolean'or type(v.effects)~='table'or v.effects==J.null or(getmetatable(v.effects)or{}).__json_array then
   self.error='Cannot read galactic_effect_overrides.json; file preserved. Repair it before saving.'
  else
   self.cfg.enabled=v.enabled
   for id,entry in pairs(v.effects)do
    local known=self.catalog[tonumber(id)]
    local valid=type(id)=='string'and type(entry)=='table'and type(entry.enabled)=='boolean'and type(entry.changes)=='table'and entry.changes~=J.null
    if valid then for k,value in pairs(entry.changes)do if not M.valid(k,value)then valid=false end end end
    if not valid or not known or not same(entry.base,known.definition)then self.stale[id]=true end
    -- Preserve old/unknown entries for repair, but they cannot be edited/applied.
    self.cfg.effects[id]=entry
   end
  end
 end
 function self:mutate(fn)
  if self.error then return nil,self.error end
  local previous=copy(self.cfg);fn()
  local ok,why=(c.mkdir or fs.mkdir)(folder)
  if ok then ok,why=fs.write(self.path..'.tmp',J.encode(self.cfg,true))end
  if ok then ok,why=fs.move(self.path..'.tmp',self.path)end
  if not ok then self.cfg=previous;fs.remove(self.path..'.tmp');return nil,why or'Cannot save effect definitions'end
  self.revision=self.revision+1;return true
 end
 function self:read(id,key,original)
  local base=assert(self.catalog[id],'Unknown effect ID').definition
  local e=not self.stale[tostring(id)]and self.cfg.effects[tostring(id)]
  if not original and e and e.changes and e.changes[key]~=nil then return e.changes[key]end
  return base[key]
 end
 function self:enabled(id)
  local e=self.cfg.effects[tostring(id)];return not self.stale[tostring(id)]and type(e)=='table'and e.enabled==true or false
 end
 function self:changed(id)
  local e=self.cfg.effects[tostring(id)];return type(e)=='table'and(e.enabled==true or type(e.changes)=='table'and next(e.changes)~=nil)or false
 end
 function self:set(id,key,value)
  if not self.catalog[id]then return nil,'Unknown effect ID'end
  if self.stale[tostring(id)]then return nil,'Definition changed since this plan was saved. Reset this ID before editing.'end
  if key~='enabled'and not M.valid(key,value)then return nil,'Invalid wire value (finite JSON numbers; other fields are uint32).'
  elseif key=='enabled'and type(value)~='boolean'then return nil,'Expected boolean'end
  return self:mutate(function()
   local k=tostring(id);local entry=self.cfg.effects[k]or{base=copy(self.catalog[id].definition),enabled=false,changes={}}
   self.cfg.effects[k]=entry
   if key=='enabled'then entry.enabled=value
   else entry.changes[key]=not same(value,entry.base[key])and copy(value)or nil end
   if not entry.enabled and next(entry.changes)==nil then self.cfg.effects[k]=nil end
  end)
 end
 function self:reset(id,key)
  if key then return self:set(id,key,self.catalog[id].definition[key])end
  local ok,why=self:mutate(function()self.cfg.effects[tostring(id)]=nil end)
  if ok then self.stale[tostring(id)]=nil end;return ok,why
 end
 function self:master(on)
  if type(on)~='boolean'then return nil,'Expected boolean'end
  return self:mutate(function()self.cfg.enabled=on end)
 end
 return self
end
return M
