-- Reversible fixed-value recipes over the editor's canonical native fields.
-- Gold is derived from the actual staged values, never from a second enable flag.
local J=require('json_data')
local M={ORDER={'god','stims'},LABELS={god={'God mode','无敌','無敵'},stims={'Infinite stims','无限治疗针','無限治療針'}}}
M.PRESET_TAB='QuickPlayer'
local function copy(v)return J.decode(J.encode(v))end
function M.valid_switches(value)
 if type(value)~='table'then return false end
 for id,on in pairs(value)do if not M.LABELS[id]or type(on)~='boolean'then return false end end
 return true
end
function M.valid_restore(value)
 if type(value)~='table'then return false end
 for id,entries in pairs(value)do
  if not M.LABELS[id]or type(entries)~='table'then return false end
  local count=0
  for key,v in pairs(entries)do
   count=count+1
   if count>80 or type(key)~='string'or #key>160 or not key:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x/[%w_]+$')
     or type(v)~='number'or v~=v or v%1~=0 or v< -2147483648 or v>4294967295 then return false end
  end
 end
 return true
end
function M.new(c)
 local self={}
 local function write(field,value)
  local ok,done,why=pcall(c.write,field,value)
  return ok and done,ok and why or done
 end
 local function persist()
  local ok,done,why=pcall(c.persist)
  return ok and done,ok and why or done
 end
 function self:state(id)
  local targets,why=c.targets(id)
  if not targets or #targets==0 then return{available=false,reason=why or'No matching component'}end
  local matched=0
  for _,t in ipairs(targets)do
   local value=c.read(t)
   if value==nil then return{available=false,reason='Unreadable field '..t.key}end
   if value==t.target then matched=matched+1 end
  end
  return{available=true,active=matched==#targets,custom=c.restore()[id]~=nil and matched<#targets,
   count=#targets,matched=matched,targets=targets}
 end
 function self:toggle(id,force,defer_persist)
  if not M.LABELS[id]then return nil,'Unknown quick modification'end
  if c.enabled and not c.enabled()then return nil,'Changes are off.'end
  local state=self:state(id);if not state.available then return nil,state.reason end
  local before=copy(c.restore());local after=copy(before);local saved=before[id]or{}
  local operations={};local on=force;if on==nil then on=not state.active end
  after[id]=on and{}or nil
  for _,t in ipairs(state.targets)do
   local current=c.read(t);local target
   if on then
    after[id][t.key]=(current==t.target and saved[t.key]~=nil)and saved[t.key]or current
    target=t.target
   elseif current==t.target then
    target=saved[t.key];if target==nil then target=c.default(t)end
   else target=current end
   if target==nil or(c.valid and not c.valid(t,target))then return nil,'Invalid restore value for '..t.key end
   operations[#operations+1]={field=t,before=current,value=target}
  end
  local function rollback(problem)
   local failures={}
   for _,op in ipairs(operations)do
    if c.read(op.field)~=op.before then
     local ok,why=write(op.field,op.before);if not ok then failures[#failures+1]=tostring(why)end
    end
   end
   c.set_restore(before);local ok,why=true;if not defer_persist then ok,why=persist()end
   if not ok then failures[#failures+1]=tostring(why)end
   return nil,tostring(problem)..(#failures>0 and('; rollback: '..table.concat(failures,'; '))or'')
  end
  for _,op in ipairs(operations)do
   local ok,why=write(op.field,op.value)
   if not ok or c.read(op.field)~=op.value then return rollback(why or'Field read-back failed')end
  end
  c.set_restore(after);local ok,why=true;if not defer_persist then ok,why=persist()end
  if not ok then return rollback(why or'Could not save quick modification')end
  return true,on
 end
 -- Presets describe recipes, while the disposable runtime cache still records exact fields plus undo context.
 -- Remove recipe-generated values and retain pre-enable manual edits as ordinary parameters. Loading on a newer
 -- game then resolves the recipe's current targets rather than replaying an old list of component offsets.
 function self:capture(values,game)
  local switches,replaced={},{}
  for _,id in ipairs(M.ORDER)do
   local state=self:state(id);switches[id]=state.available and state.active or false
   if switches[id]then
    local saved=c.restore()[id]or{}
    for _,t in ipairs(state.targets)do
     local baseline=saved[t.key];if baseline==nil then baseline=c.default(t)end
     local default=c.default(t)
     if baseline==nil or(c.valid and not c.valid(t,baseline))then return nil,'Invalid quick preset baseline: '..t.key end
     local hash,part=t.key:match('^(%x+)/(.+)$')
     replaced[t.key]=baseline~=default and{hash=hash,id=part,value=baseline}or false
    end
   end
  end
  local out={}
  for _,v in ipairs(values)do if replaced[v.hash..'/'..v.id]==nil then out[#out+1]=copy(v)end end
  local keys={};for key in pairs(replaced)do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys)do if replaced[key]then out[#out+1]=replaced[key]end end
  game=copy(game);game.quick_restore=nil;game.quick_switches=switches
  return out,game
 end
 -- Off first, then ordinary preset parameters, then on: an off switch cannot clobber an explicit manual value.
 -- False with no recipe-owned undo context leaves manually authored matching values alone.
 function self:apply_switches(switches,on)
  if not M.valid_switches(switches)then return nil,'Invalid quick modification switches'end
  for _,id in ipairs(M.ORDER)do
   if switches[id]==on and(on or c.restore()[id]~=nil)then
    local ok,why=self:toggle(id,on,true);if not ok then return nil,why end
   end
  end
  return true
 end
 return self
end
-- Restore contexts follow selected parameter values during a preset merge.
-- They are undo metadata, not additional game fields or duplicate preview rows.
function M.merge_restore(target,source,ref)
 local src=source.data and source.data.game and source.data.game.quick_restore
 if not src then return end
 target.data=target.data or{};target.data.game=target.data.game or{}
 local dst=target.data.game.quick_restore or{};target.data.game.quick_restore=dst
 for feature,entries in pairs(src)do for _,id in ipairs(ref.ids or{})do
  local key=ref.hash..'/'..id
  if entries[key]~=nil then dst[feature]=dst[feature]or{};dst[feature][key]=entries[key]end
 end end
end
return M
