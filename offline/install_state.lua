-- Installed plan identity is distinct from reset defaults and disposable caches.
-- Revisions only invalidate a cache: equality compares the actual desired state.
local J=require('json_data')
local P=require('portable_file')
local M={}
function M.new(o)
 local fs=o.fs or require('preset_files')
 local self={options=o,fs=fs}
 local raw=fs.read(o.path)
 if raw then
  local ok,v=pcall(J.decode,raw)
  if ok and type(v)=='table' and v.version==1 and v.identity==o.identity()
     and type(v.snapshot)=='table' and type(v.snapshot.tables)=='table' then self.baseline=v.snapshot end
 end
 function self:read_baseline()
  if not self.baseline then
   self.baseline=o.empty();self.baseline.tables=o.snapshot().tables
  else
   for key,value in pairs(o.empty())do if self.baseline[key]==nil then self.baseline[key]=value end end
  end
  self.revision=nil
 end
 function self:pending(revision)
  if not self.baseline then return false end
  if self.revision~=revision then
   self.current=o.snapshot();self.dirty=J.encode(self.current)~=J.encode(self.baseline)
   self.revision=revision
  end
  return self.dirty
 end
 function self:committed()
  local snapshot=o.snapshot()
  -- The in-memory baseline advances only after the game/asset transaction has
  -- succeeded. A marker-save failure cannot turn a failed install into success.
  self.baseline=snapshot;self.revision=nil
  return P.save(o.path,J.encode({version=1,identity=o.identity(),snapshot=snapshot}),{fs=fs,backup=false})
 end
 function self:restored()
  self.baseline=nil;self.revision=nil;fs.remove(o.path)
 end
 return self
end
return M
