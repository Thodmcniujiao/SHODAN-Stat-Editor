-- One authoring store for the original stat rows and the independent-entity page.
-- These are virtual fields: they never write a shared DestructionSettings pointer.
local I=require('install')
local ffi=require('ffi')
local B={};B.__index=B
local function hex(key)
 local t={};for i=8,1,-1 do t[#t+1]=string.format('%02X',key:byte(i))end;return table.concat(t)
end
local function copy(values)
 local out={};for id,slots in pairs(values)do out[id]={};for key,v in pairs(slots)do out[id][key]=v end end;return out
end
function B.new(panel,options)return setmetatable({panel=panel,options=options or{},fields={}},B)end
function B:rows(key)
 if type(key)~='string'or #key~=8 then return{}end
 local hash=hex(key);local model=self.panel.model
 local target=model.by_id['E'..hash]or model.by_id['U'..hash]
 if not target or target.why then return{}end
 local rows={}
 for _,level in ipairs(target.levels)do
  local name='entity_demolition:'..target.id..':'..level.key
  local f=self.fields[name]
  if not f then
   f={key=name,storage='virtual',limit=4294967295,users={},demolition=self,target=target,level=level}
   self.fields[name]=f
  end
  rows[#rows+1]={field=f,level=level.level,hit=level.hit}
 end
 return rows
end
function B:read(f,base)return base and f.level.value or self.panel:value(f.target,f.level)end
function B:own(f)return(self.panel.values[f.target.id]or{})[f.level.key]end
function B:write(f,value)
 if self:own(f)==value then return true end
 return self.panel:set(f.target.id,f.level.key,value)
end
function B:clear()
 local before,stale=self.panel.values,self.panel.stale
 if not next(before)and not next(stale)then return true end
 self.panel.values,self.panel.stale={},{}
 local ok,why=self.panel:persist()
 if not ok then self.panel.values,self.panel.stale=before,stale end
 return ok,why
end
function B:migrate(records)
 if #records==0 then return true end
 -- Backup both inputs before saving or removing any legacy row. A retry is safe:
 -- an existing canonical slot always wins over a legacy config.txt value.
 local parent=self.options.backup_root or(I.home..'/demolition-migration-backups')
 I.mkdirs(parent)
 local stem=parent..'/'..os.date('%Y%m%d-%H%M%S');local folder=stem;local suffix=0
 while ffi.C.GetFileAttributesA(folder)~=0xFFFFFFFF do suffix=suffix+1;folder=stem..'-'..suffix end
 I.mkdirs(folder)
 local report={'Canonical store: entity_demolition.txt. Existing canonical slots win legacy conflicts.'}
 for _,item in ipairs({{'config.txt',self.options.config_path},{'entity_demolition.txt',self.panel.options.path}})do
  local bytes=item[2]and I.read(item[2])
  if bytes then
   local file,why=io.open(folder..'/'..item[1],'wb');if not file then return nil,why end
   local ok,err=file:write(bytes);file:close();if not ok then return nil,err end
  end
 end
 local before=self.panel.values;local merged=copy(before)
 for _,r in ipairs(records)do
  local f=r.field;local id,key=f.target.id,f.level.key
  merged[id]=merged[id]or{}
  local existing=(before[id]or{})[key]
  if existing==nil then merged[id][key]=r.value end
  report[#report+1]=string.format('%s %s legacy=%.0f canonical=%.0f%s',id,key,r.value,
   existing==nil and r.value or existing,existing~=nil and' (kept canonical)'or' (imported)')
 end
 local valid,problem=pcall(function()self.panel.model:validate(merged)end)
 if not valid then return nil,tostring(problem)end
 local file,why=io.open(folder..'/migration.txt','wb');if not file then return nil,why end
 local wrote,err=file:write(table.concat(report,'\n')..'\n');file:close();if not wrote then return nil,err end
 self.panel.values=merged
 local ok,err=self.panel:persist()
 if not ok then self.panel.values=before;return nil,err end
 self.migration_backup=folder
 if self.options.log then self.options.log('demolition: unified '..#records..' legacy rows; backup: '..folder)end
 return true
end
return B
