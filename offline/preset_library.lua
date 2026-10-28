-- One named preset library. Legacy files are read as imports, never rewritten.
local J=require('json_data')
local I=require('install')
local M={SCOPES={game=true,enemy=true,loadout=true,preload=true}}
local Library={};Library.__index=Library
local function copy(value)return J.decode(J.encode(value),32*1024*1024)end
M.copy=copy
local function integer(n)return type(n)=='number'and n%1==0 and n>=1 and n<=100000000 end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e100 end
local function name(text)
 assert(type(text)=='string','Preset name must be text')
 text=text:gsub('[%z\1-\31\127]',''):match('^%s*(.-)%s*$')
 assert(text~='','Preset name is empty')
 if #text>120 then text=text:sub(1,120):gsub('[\194-\244][\128-\191]*$','')end
 return text
end
M.name=name
local function validate(p)
 assert(type(p)=='table'and integer(p.id)and M.SCOPES[p.scope],'Invalid preset identity or scope')
 p.name=name(p.name)
 assert(p.kind=='snapshot'or p.kind=='patch','Invalid preset application mode')
 assert(type(p.values)=='table'and #p.values<=100000,'Invalid preset values')
 for _,v in ipairs(p.values)do
  assert(type(v)=='table'and type(v.hash)=='string'and v.hash:match('^'..string.rep('%x',16)..'$')
   and type(v.id)=='string'and v.id:match('^[%w_]+$')and finite(v.value),'Invalid parameter entry')
 end
 if p.data~=nil then assert(type(p.data)=='table','Invalid preset payload')end
 return p
end
local function disk_io()
 return {read=I.read,write=function(path,raw)
  local f,why=io.open(path,'wb');if not f then return nil,why end
  local ok,err=f:write(raw);local closed,close_error=f:close()
  if not ok or not closed then return nil,err or close_error end
  if I.read(path)~=raw then return nil,'Preset write verification failed'end;return true
 end,move=function(a,b)if I.move_file(a,b,9)==0 then return nil,'Could not replace preset library'end;return true end,
 remove=os.remove}
end
function M.new(o)
 local self=setmetatable({path=assert(o.path),io=o.io or disk_io(),document={version=1,next_id=1,items={},imports={}},revision=0},Library)
 self.baseline=self.io.read(self.path)
 if self.baseline then
  local doc=J.decode(self.baseline,32*1024*1024)
  assert(doc.version==1 and type(doc.items)=='table'and type(doc.imports)=='table'and integer(doc.next_id),'Unsupported preset library')
  local ids={};assert(#doc.items<=10000,'Too many presets')
  for _,p in ipairs(doc.items)do validate(p);assert(not ids[p.id],'Duplicate preset ID');ids[p.id]=true;assert(doc.next_id>p.id,'Invalid next preset ID')end
  self.document=doc
 end
 return self
end
function Library:transaction(fn)
 local before=copy(self.document)
 local ok,result=pcall(function()
  fn(self.document)
  assert(self.io.read(self.path)==self.baseline,'Preset library changed in another editor; restart before saving')
  local raw=J.encode(self.document);assert(#raw<=32*1024*1024,'Preset library is too large')
  local temporary=self.path..'.new'
  local done,why=self.io.write(temporary,raw);assert(done,why)
  if self.io.read(temporary)~=raw then self.io.remove(temporary);error('Preset temporary file differs')end
  if self.io.read(self.path)~=self.baseline then self.io.remove(temporary);error('Preset library changed before replacement')end
  done,why=self.io.move(temporary,self.path);if not done then self.io.remove(temporary);error(why)end
  assert(self.io.read(self.path)==raw,'Preset library read-back differs')
  self.baseline=raw;self.revision=self.revision+1
 end)
 if not ok then self.document=before;return nil,tostring(result)end
 return true
end
function Library:get(id)for _,p in ipairs(self.document.items)do if p.id==id then return p end end end
function Library:list(scope)
 local out={};for _,p in ipairs(self.document.items)do if not scope or p.scope==scope then out[#out+1]=p end end
 table.sort(out,function(a,b)return a.id<b.id end);return out
end
function Library:create(scope,title,payload,kind)
 assert(M.SCOPES[scope],'Invalid scope');local id=self.document.next_id
 local p=validate({id=id,scope=scope,name=title,kind=kind or'snapshot',values=copy(payload.values or{}),data=payload.data and copy(payload.data)or nil})
 local ok,why=self:transaction(function(doc)assert(#doc.items<10000,'Too many presets');doc.items[#doc.items+1]=p;doc.next_id=id+1 end)
 return ok and id or nil,why
end
function Library:rename(id,title)
 local p=self:get(id);if not p then return nil,'Preset no longer exists'end
 local ok,value=pcall(name,title);if not ok then return nil,tostring(value)end
 return self:transaction(function()p.name=value end)
end
function Library:replace(id,payload)
 local p=self:get(id);if not p then return nil,'Preset no longer exists'end
 local updated=validate({id=id,name=p.name,scope=p.scope,kind=p.kind,values=copy(payload.values or{}),data=payload.data and copy(payload.data)or nil})
 return self:transaction(function(doc)for n,item in ipairs(doc.items)do if item.id==id then doc.items[n]=updated;return end end end)
end
function Library:delete(id)
 if not self:get(id)then return nil,'Preset no longer exists'end
 return self:transaction(function(doc)for n,p in ipairs(doc.items)do if p.id==id then table.remove(doc.items,n);return end end end)
end
-- Import batches have stable source identities, so deleting an imported preset will
-- not cause the legacy slot to reappear on the next launch. Source files stay intact.
function Library:import_legacy(folder,parse_number)
 local pending={};local read=self.io.read
 local function add(origin,scope,title,payload,kind)
  if self.document.imports[origin]then return end
  pending[#pending+1]={origin=origin,scope=scope,name=title,payload=payload,kind=kind or'snapshot'}
 end
 for _,enemy in ipairs({false,true})do for n=1,50 do
  local filename=string.format(enemy and'enemy_preset_%02d.txt'or'preset_%02d.txt',n)
  local raw=read(folder..'/'..filename)
  if raw then
   local title,values,cleared='Preset '..n,{},false
   for line in raw:gmatch('[^\r\n]+')do
    line=line:gsub('#.*$','')
    if line:match('^%s*cleared')then cleared=true;break end
    title=line:match('^%s*name%s+(.-)%s*$')or title
    local hash,key,amount=line:match('^%s*(%x+)%s+([%w_]+)%s+(%S+)')
    local v=hash and #hash==16 and parse_number(amount)
    if finite(v)then values[#values+1]={hash=hash:upper(),id=key,value=v}end
   end
   if not cleared then add(filename,enemy and'enemy'or'game',title,{values=values})end
  end
 end end
 local groups={}
 for line in(read(folder..'/weapon_presets.txt')or''):gmatch('[^\r\n]+')do
  line=line:gsub('#.*$','');local hash,slot,tail=line:match('^%s*(%x+)%s+(%d+)%s+(.-)%s*$')
  slot=tonumber(slot)
  if hash and #hash==16 and slot and slot>=1 and slot<=5 then
   local id=hash:upper()..'/'..slot;groups[id]=groups[id]or{}
   local key,amount=tail:match('^([%w_]+)%s+(%S+)$');local v=key and parse_number(amount)
   if finite(v)then groups[id][#groups[id]+1]={hash=hash:upper(),id=key,value=v}end
  end
 end
 local keys={};for key in pairs(groups)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do add('weapon/'..key,'game','旧单项预设 '..key,{values=groups[key],data={owner_hash=key:sub(1,16)}},'patch')end
 local loadout=read(folder..'/player_save_presets.json')
 if loadout then
  local ok,t=pcall(J.decode,loadout,1024*1024)
  if ok and type(t)=='table'then for slot,values in pairs(t)do if type(values)=='table'then
   add('loadout/'..slot,'loadout','旧存档配装 '..slot,{data={version=0x107,values=values}})
  end end end
 end
 local preload=read(folder..'/preload_config.json')
 if preload then
  local ok,t=pcall(J.decode,preload,32*1024*1024)
  if ok and type(t)=='table'and type(t.presets)=='table'then
   local sorted={};for key in pairs(t.presets)do sorted[#sorted+1]=key end;table.sort(sorted)
   for _,key in ipairs(sorted)do if type(t.presets[key])=='table'then
    add('preload/'..key,'preload','旧预载方案 '..key,{data={legacy_key=key,value=t.presets[key]}},'patch')
   end end
  end
 end
 if #pending==0 then return true,0 end
 local ok,why=self:transaction(function(doc)
  assert(#doc.items+#pending<=10000,'Too many presets to import')
  for _,entry in ipairs(pending)do
   local id=doc.next_id;doc.next_id=id+1
   doc.items[#doc.items+1]=validate({id=id,name=entry.name,scope=entry.scope,kind=entry.kind,
    values=entry.payload.values or{},data=entry.payload.data})
   doc.imports[entry.origin]=true
  end
 end)
 return ok,ok and #pending or why
end
return M
