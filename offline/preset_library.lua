-- One named preset library. Legacy files are read as imports, never rewritten.
-- Storage: a folder (o.dir: the Presets folder beside the exe), one file per preset named after it (精英.json,
-- Horde.json; format FORMAT, its id inside) and preset_index.json (the next id, the import markers). Copying a
-- preset file into the folder adds it (a clashing id is given a new one). o.path: the older single-file library
-- (preset_library.json), still read to import it.
local J=require('json_data')
local I=require('install')
local M={SCOPES={global=true,game=true,enemy=true,loadout=true,preload=true},INDEX='preset_index.json',OLD='preset_library.json',
 FORMAT='SHODAN Stat Editor preset'}
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
local function group(text)
 text=(text or''):gsub('\\','/'):gsub('^/+',''):gsub('/+$','')
 assert(#text<=240,'Group path is too long')
 local parts={}
 for part in text:gmatch('[^/]+')do
  assert(part~='.'and part~='..'and not part:find('[<>:"|%?%*%z\1-\31]')and not part:find('[%. ]$'),'Invalid group folder')
  local device=part:match('^[^%.]+'):upper()
  assert(part:sub(1,1)~='.'and part:lower()~='backup'and device~='CON'and device~='PRN'and device~='AUX'and device~='NUL'
   and not device:match('^COM[1-9]$')and not device:match('^LPT[1-9]$'),'Reserved group folder')
  parts[#parts+1]=part
 end
 assert(#parts<=16,'Too many nested groups');return table.concat(parts,'/')
end
M.group=group
local function description(text)
 assert(text==nil or type(text)=='string','Preset description must be text')
 text=(text or''):gsub('\r\n','\n'):gsub('[%z\1-\8\11-\31\127]','')
 assert(#text<=4096,'Description is too long');return text
end
local function validate(p)
 assert(type(p)=='table'and integer(p.id)and M.SCOPES[p.scope],'Invalid preset identity or scope')
 p.name=name(p.name)
 p.description=description(p.description);p.group=group(p.group)
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
-- a preset's file name: its name without the characters Windows refuses (and not a reserved device name);
-- `taken` (lower-case names) keeps two presets of one name apart: 'Horde.json', 'Horde (2).json'
local RESERVED={CON=true,PRN=true,AUX=true,NUL=true}
for i=1,9 do RESERVED['COM'..i]=true;RESERVED['LPT'..i]=true end
local function file_name(title,taken)
 local base=title:gsub('[<>:"/\\|%?%*%z\1-\31]','_'):gsub('[%. ]+$',''):match('^%s*(.-)%s*$')
 if base==''then base='preset'end
 if #base>80 then base=base:sub(1,80):gsub('[\194-\244][\128-\191]*$','')end
 if RESERVED[base:upper()]then base='_'..base end
 local name,n=base..'.json',1
 while taken[name:lower()]do n=n+1;name=base..' ('..n..').json'end
 taken[name:lower()]=true
 return name
end
M.file_name=file_name
local function write_atomic(io,path,raw)
 local temporary=path..'.new'
 local done,why=io.write(temporary,raw);assert(done,why)
 if io.read(temporary)~=raw then io.remove(temporary);error('Preset temporary file differs: '..path)end
 done,why=io.move(temporary,path);if not done then io.remove(temporary);error(why or'Could not replace '..path)end
 assert(io.read(path)==raw,'Preset read-back differs: '..path)
end
local function by_id(a,b)return a.id<b.id end
function M.open_folder(o)
 local dir=assert(o.dir)
 local self=setmetatable({dir=dir,path=dir..'/'..M.INDEX,io=o.io or require('preset_files'),readonly=o.readonly,
  document={version=1,next_id=1,items={},imports={}},files={},disk_raw={},foreign={},folders={},revision=0},Library)
 self.baseline=self.io.read(self.path)
 if self.baseline then
  local index=J.decode(self.baseline,32*1024*1024)
  assert(index.version==2 and type(index.imports)=='table'and integer(index.next_id),'Unsupported preset index')
  self.document.imports,self.document.next_id=index.imports,index.next_id
 end
 local loaded,dirty={},false
 local paths,folders=self.io.list(dir)
 for _,folder in ipairs(folders or{})do self.folders[group(folder)]=true end
 for _,name in ipairs(paths or{})do
  local lower=name:lower()
  if lower:match('%.json$')and lower~=M.INDEX and lower~=M.OLD then
   local raw=self.io.read(dir..'/'..name)
   local ok,p=pcall(function()local t=J.decode(raw,32*1024*1024);assert(type(t)=='table'and t.format==M.FORMAT,'not a preset file');return t end)
   if ok then loaded[#loaded+1]={name=name,p=p,raw=raw}
   else self.foreign[lower]=true;if o.log then o.log('presets: '..name..' left alone: '..tostring(p))end end
  end
 end
 table.sort(loaded,function(a,b)
  local ia,ib=integer(a.p.id)and a.p.id or math.huge,integer(b.p.id)and b.p.id or math.huge
  if ia~=ib then return ia<ib end;return a.name<b.name
 end)
 local next_id=self.document.next_id
 for _,e in ipairs(loaded)do if integer(e.p.id)then next_id=math.max(next_id,e.p.id+1)end end
 local seen={}
 for _,e in ipairs(loaded)do
  local p={id=e.p.id,scope=e.p.scope,name=e.p.name,kind=e.p.kind,values=e.p.values,data=e.p.data,
   description=e.p.description,group=e.name:match('^(.*)/[^/]+$')or''}
  if not integer(p.id)or seen[p.id]then p.id=next_id;next_id=next_id+1;dirty=true end
  local ok,why=pcall(validate,p)
  if ok and #self.document.items<10000 then
   seen[p.id]=true;self.document.items[#self.document.items+1]=p;self.files[p.id]=e.name;self.disk_raw[e.name]=e.raw
  else self.foreign[e.name:lower()]=true;if o.log then o.log('presets: '..e.name..' not loaded: '..tostring(why))end end
 end
 table.sort(self.document.items,by_id)
 self.document.next_id=next_id
 -- a preset file without its place in the index (copied in, or a new id): the folder settled once
 if not self.readonly and(dirty or(#self.document.items>0 and not self.baseline))then
  local ok,why=self:transaction(function()end);assert(ok,why)
 end
 return self
end
function M.new(o)
 if o.dir then return M.open_folder(o)end
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
-- the folder: every preset its own file (written only when it changed), then the index; a renamed or
-- deleted preset's old file removed
function Library:folder_transaction(fn)
 local before,before_files=copy(self.document),{}
 for id,name in pairs(self.files)do before_files[id]=name end
 local ok,result=pcall(function()
  assert(not self.readonly,'Preset folder opened read-only')
  fn(self.document)
  assert(self.io.read(self.path)==self.baseline,'Preset folder changed in another editor; restart before saving')
  for path,raw in pairs(self.disk_raw)do assert(self.io.read(self.dir..'/'..path)==raw,'Preset file changed or moved outside the editor; restart before saving: '..path)end
  local items={};for _,p in ipairs(self.document.items)do items[#items+1]=p end;table.sort(items,by_id)
  local taken={[M.INDEX]=true,[M.OLD]=true};for name in pairs(self.foreign)do taken[name]=true end
  local want,used={},{}
  for _,p in ipairs(items)do
   p.group=group(p.group)
   local prefix=p.group~=''and(p.group..'/')or''
   local local_taken={};for path in pairs(taken)do if path:sub(1,#prefix)==prefix:lower()then local_taken[path:sub(#prefix+1)]=true end end
   local name=prefix..file_name(p.name,local_taken);taken[name:lower()]=true;want[p.id]=name;used[name]=true
   if p.group~=''and self.io.mkdir then
    local folder=self.dir;for part in p.group:gmatch('[^/]+')do folder=folder..'/'..part;assert(self.io.mkdir(folder),'Could not create group folder: '..folder)end
   end
  end
  local next_raw={}
  for _,p in ipairs(items)do
   local raw=J.encode({format=M.FORMAT,version=1,id=p.id,name=p.name,description=p.description,scope=p.scope,kind=p.kind,values=p.values,data=p.data})
   local path=self.dir..'/'..want[p.id]
   assert(not self.io.read(path)or self.disk_raw[want[p.id]],'Preset destination appeared outside the editor; restart before saving: '..want[p.id])
   if self.files[p.id]~=want[p.id]or self.io.read(path)~=raw then write_atomic(self.io,path,raw)end
   next_raw[want[p.id]]=raw
  end
  for _,name in pairs(self.files)do if not used[name]then self.io.remove(self.dir..'/'..name)end end
  local index=J.encode({version=2,next_id=self.document.next_id,imports=self.document.imports})
  if index~=self.baseline then write_atomic(self.io,self.path,index)end
  self.files=want;self.disk_raw=next_raw;self.baseline=index;self.revision=self.revision+1
 end)
 if not ok then self.document,self.files=before,before_files;return nil,tostring(result)end
 return true
end
function Library:transaction(fn)
 if self.dir then return self:folder_transaction(fn)end
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
 local p=validate({id=id,scope=scope,name=title,description=payload.description,group=payload.group,kind=kind or'snapshot',values=copy(payload.values or{}),data=payload.data and copy(payload.data)or nil})
 local ok,why=self:transaction(function(doc)assert(#doc.items<10000,'Too many presets');doc.items[#doc.items+1]=p;doc.next_id=id+1 end)
 return ok and id or nil,why
end
function Library:groups()
 local found={['']=true};for folder in pairs(self.folders or{})do found[folder]=true end
 for _,p in ipairs(self.document.items)do found[p.group or'']=true end
 local out={};for folder in pairs(found)do out[#out+1]=folder end;table.sort(out);return out
end
function Library:create_group(title)
 if self.readonly then return nil,'Preset folder opened read-only'end
 local ok,value=pcall(group,title);if not ok then return nil,tostring(value)end
 if value==''then return nil,'Group name is empty'end
 if self.dir and self.io.mkdir then
  local folder=self.dir;for part in value:gmatch('[^/]+')do folder=folder..'/'..part;local done=self.io.mkdir(folder);if not done then return nil,'Could not create group folder'end end
 end
 self.folders=self.folders or{};self.folders[value]=true;self.revision=self.revision+1;return true,value
end
function Library:metadata(id,field,value)
 local p=self:get(id);if not p then return nil,'Preset no longer exists'end
 if field~='description'and field~='group'then return nil,'Unknown preset metadata'end
 local ok,clean=pcall(field=='group'and group or description,value);if not ok then return nil,tostring(clean)end
 return self:transaction(function()p[field]=clean end)
end
function Library:rename(id,title)
 local p=self:get(id);if not p then return nil,'Preset no longer exists'end
 local ok,value=pcall(name,title);if not ok then return nil,tostring(value)end
 return self:transaction(function()p.name=value end)
end
function Library:replace(id,payload)
 local p=self:get(id);if not p then return nil,'Preset no longer exists'end
 local updated=validate({id=id,name=p.name,description=p.description,group=p.group,scope=payload.scope or p.scope,kind=payload.kind or p.kind,values=copy(payload.values or{}),data=payload.data and copy(payload.data)or nil})
 return self:transaction(function(doc)for n,item in ipairs(doc.items)do if item.id==id then doc.items[n]=updated;return end end end)
end
function Library:delete(id)
 if not self:get(id)then return nil,'Preset no longer exists'end
 return self:transaction(function(doc)for n,p in ipairs(doc.items)do if p.id==id then table.remove(doc.items,n);return end end end)
end
-- Move the old profile library into the portable folder without changing its source.
-- Copy the old import tombstones too: deleted quick slots must never reappear.
function Library:import_library(path)
 if path==self.path then return true,0 end
 local raw=self.io.read(path);if not raw then return true,0 end
 return self:import_from(M.new({path=path,io=self.io}),'library/'..path..'/')
end
-- Another Presets folder (the last build's): its presets copied once, deletions there and here respected.
function Library:import_folder(dir)
 if dir==self.dir then return true,0 end
 local ok,source=pcall(M.open_folder,{dir=dir,io=self.io,readonly=true})
 if not ok then return nil,tostring(source)end
 return self:import_from(source,'folder/'..dir..'/')
end
function Library:import_from(source,prefix)
 local pending={}
 for _,p in ipairs(source.document.items)do
  local origin=prefix..p.id
  if not self.document.imports[origin]then pending[#pending+1]={origin=origin,preset=p}end
 end
 local missing=false;for origin in pairs(source.document.imports)do if not self.document.imports[origin]then missing=true end end
 if #pending==0 and not missing then return true,0 end
 local ok,why=self:transaction(function(doc)
  assert(#doc.items+#pending<=10000,'Too many presets to migrate')
  for _,entry in ipairs(pending)do
   local p=copy(entry.preset);p.id=doc.next_id;doc.next_id=p.id+1
   doc.items[#doc.items+1]=validate(p);doc.imports[entry.origin]=true
  end
  for origin in pairs(source.document.imports)do doc.imports[origin]=true end
 end)
 return ok,ok and #pending or why
end
-- Old categories did not contain the other sections. Preserve their recorded
-- contents as explicit partial imports; newly saved/replaced presets are global snapshots.
function Library:globalize()
 local found=false;for _,p in ipairs(self.document.items)do if p.scope~='global'then found=true;break end end
 if not found then return true end
 return self:transaction(function(doc)
  for _,p in ipairs(doc.items)do if p.scope~='global'then
   local scope,old=p.scope,p.data
   local data={version=2,legacy_scope=scope}
   if scope=='game'and old and old.stacks and old.own_off then data.game=old
   elseif scope=='loadout'then data.loadout=old
   elseif scope=='preload'and old then
    if old.legacy_key then data.legacy_preload=old else data.preload=old end
   end
   p.scope,p.kind,p.data='global','patch',data
  end end
 end)
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
