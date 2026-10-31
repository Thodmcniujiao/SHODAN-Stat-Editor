-- Small portable configuration files: verified staging, atomic replace and one
-- previous valid revision. Never overwrite a damaged input without preserving it.
local M={}
local function valid(raw,check)
 if type(raw)~='string' then return false end
 if not check then return true end
 local ok,result=pcall(check,raw);return ok and result~=false and result~=nil
end
function M.read(path,o)
 o=o or{};local fs=o.fs or require('preset_files')
 local raw=fs.read(path)
 if valid(raw,o.validate) then return raw end
 local backup=fs.read(path..'.bak')
 if valid(backup,o.validate) then return backup,'Recovered previous configuration',true end
 return nil,raw and 'Invalid configuration; original file preserved' or nil
end
function M.save(path,raw,o)
 o=o or{};local fs=o.fs or require('preset_files')
 if not valid(raw,o.validate) then return nil,'Invalid configuration output' end
 local previous=fs.read(path)
 if previous==raw then return true end
 local temp=path..'.tmp'
 local function cleanup(why) fs.remove(temp);return nil,why end
 local function stage(target,data)
  local ok,why=fs.write(target,data)
  if not ok then fs.remove(target);return nil,why end
  if fs.read(target)~=data then fs.remove(target);return nil,'Configuration read-back failed: '..target end
  return true
 end
 local ok,why=stage(temp,raw);if not ok then return nil,why end
 if previous and(o.backup~=false or not valid(previous,o.validate))then
  local destination=path..(valid(previous,o.validate) and '.bak' or '.corrupt')
  ok,why=stage(destination..'.tmp',previous)
  if ok then ok,why=fs.move(destination..'.tmp',destination) end
  if not ok then fs.remove(destination..'.tmp');return cleanup(why) end
 end
 if fs.read(path)~=previous then return cleanup('Configuration changed while saving; reload before retrying') end
 ok,why=fs.move(temp,path)
 if not ok then return cleanup(why) end
 return true
end
return M
