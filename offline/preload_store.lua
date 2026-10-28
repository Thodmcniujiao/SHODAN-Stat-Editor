-- File-backed package editing and additive preload plans; no process or network calls.
local D=require('demolition')
local J=require('json_data')
local I=require('install')
local G=require('gamedata')
local ffi=require('ffi')
local DATA=require('preload_data')
local M={};M.__index=M
local function copy(t)return J.decode(J.encode(t),128*1024*1024)end
local function keys(t)local a={};for k in pairs(t or{})do a[#a+1]=k end;table.sort(a);return a end
M.keys=keys
function M.hash(s)
 s=tostring(s):match('^%s*(.-)%s*$')
 local h=s:match('^0[xX](%x+)$')or s:match('^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)$')
 if h and #h<=16 then return(string.rep('0',16-#h)..h):upper()end
 if s:match('^%d+$')then
  local lo,hi=require('stratagem_components').parse_u64(s);assert(lo,hi)
  return string.format('%08X%08X',hi,lo)
 end
 assert(s~=''and not s:find('[%c]'),'empty or invalid resource name')
 return D.hex(D.hash_resource(s))
end
M.PTYPE='AD9C6D9ED1E5E77A'
function M.input_hash(s)
 s=tostring(s):match('^%s*(.-)%s*$')
 if s:match('^%d+$')then
  local lo,hi=require('stratagem_components').parse_u64(s);assert(lo,hi);return string.format('%08X%08X',hi,lo)
 end
 return M.hash(s)
end
function M.parse_package(s)
 assert(#s>=16,'package header truncated')
 local n=D.u32(s,8);assert(n<=1000000 and 16+n*16<=#s,'invalid package array')
 local out={};for i=0,n-1 do local at=16+i*16
  out[#out+1]={type=D.hex(s:sub(at+1,at+8)),name=D.hex(s:sub(at+9,at+16))}
 end
 return out
end
function M.package_bytes(original,entries)
 M.parse_package(original);assert(#entries<=1000000,'too many package resources')
 local a={original:sub(1,8),D.p32(#entries),original:sub(13,16)}
 for _,e in ipairs(entries)do a[#a+1]=D.unhex(M.hash(e.type))..D.unhex(M.hash(e.name))end
 local n=D.u32(original,8);a[#a+1]=original:sub(17+n*16)
 return table.concat(a)
end
local function unique(entries)
 local seen,out={},{};for _,e in ipairs(entries)do local k=e.type..e.name
  if not seen[k]then seen[k]=true;out[#out+1]={type=e.type,name=e.name}end
 end;return out
end
function M.new(options)
 local cfg={version=1,edits={},selected={},targets={['18235E0C9EC0E636']=true},arrays={},presets={}}
 local saved=I.read(options.path or'')
 if saved then local parsed=J.decode(saved,128*1024*1024);assert(parsed.version==1,'unsupported preload configuration');cfg=parsed end
 for _,k in ipairs({'edits','selected','targets','arrays','presets'})do cfg[k]=cfg[k]or{};assert(type(cfg[k])=='table','invalid preload section: '..k)end
 return setmetatable({options=options,cfg=cfg,arrays={},version=0,report={},catalog=DATA.catalog},M)
end
function M:save()
 local p=self.options.path
 if p then
  local text=J.encode(self.cfg);local tmp=p..'.new';local f=assert(io.open(tmp,'wb'));assert(f:write(text));f:close()
  assert(I.read(tmp)==text,'preload configuration read-back failed')
  assert(I.move_file(tmp,p,9)~=0,'could not save preload configuration')
 end
 self.report={};self.version=self.version+1;if self.options.changed then self.options.changed()end
 return true
end
function M:mutate(fn)
 local old=copy(self.cfg);local ok,why=pcall(function()fn();self:save()end)
 if not ok then self.cfg=old;return nil,tostring(why)end;return true
end
function M:has_changes()
 return next(self.cfg.edits)~=nil or next(self.cfg.arrays)~=nil or(self.cfg.merge_enabled~=false and next(self.cfg.selected)~=nil)
end
function M:signature()
 if self.signature_version~=self.version then
  self.signature_value=D.hex(D.hash_resource(J.encode({edits=self.cfg.edits,arrays=self.cfg.arrays,
   selected=self.cfg.selected,targets=self.cfg.targets,merge_enabled=self.cfg.merge_enabled~=false})))
  self.signature_version=self.version
 end
 return self.signature_value
end
function M:original(h)
 h=M.hash(h);assert(self.catalog[h],'package is absent from catalog: '..h)
 local raw=self.options.load(h);M.parse_package(raw);return raw
end
function M:entries(h)
 h=M.hash(h);return copy(self.cfg.edits[h]and self.cfg.edits[h].entries or M.parse_package(self:original(h)))
end
function M:set_entries(h,entries)
 h=M.hash(h);local raw=self:original(h);local out={}
 for _,e in ipairs(entries)do out[#out+1]={type=M.hash(e.type),name=M.hash(e.name)}end
 M.package_bytes(raw,out)
 return self:mutate(function()self.cfg.edits[h]={expected=D.hex(D.hash_resource(raw)),entries=out}end)
end
function M:edit_entry(h,index,text)
 local entries=self:entries(h)
 if text:match('^%s*[-]?%s*$')then assert(entries[index],'no entry to delete');table.remove(entries,index)
 else
  local typ,name=text:match('^%s*(%S+)%s+(.+)%s*$');assert(typ and name,'Enter: resource_type resource_path_or_hash; use - to remove')
  assert(index>=1 and index<=#entries+1,'invalid entry index');entries[index]={type=M.input_hash(typ),name=M.input_hash(name)}
 end
 return self:set_entries(h,entries)
end
function M:toggle(kind,h,value)
 assert(kind=='selected'or kind=='targets');h=M.hash(h);assert(self.catalog[h],'unknown package')
 return self:mutate(function()self.cfg[kind][h]=value and true or nil end)
end
function M:select_many(list,value)
 return self:mutate(function()for _,h in ipairs(list)do assert(self.catalog[h],'unknown package');self.cfg.selected[h]=value and true or nil end end)
end
function M:expand(selected)
 local entries,done,active,packages={},{},{},{}
 local function visit(h)
  if active[h]then return end -- Cyclic descriptor graphs still have a finite union of leaf resources.
  if done[h]then return end
  active[h]=true;packages[#packages+1]=h
  if #packages%32==0 and self.options.pump then assert(self.options.pump()~=false,'preload generation cancelled')end
  for _,e in ipairs(self:entries(h))do
   -- A package descriptor alone does not prove content residency. Expand its leaf resources.
   if e.type==M.PTYPE then assert(self.catalog[e.name],'unresolved nested package: '..e.name);visit(e.name)
   else entries[#entries+1]=e end
  end
  active[h]=nil;done[h]=true
 end
 for _,h in ipairs(keys(selected))do visit(h)end
 return unique(entries),packages
end
function M:package_outputs()
 local out={};for h,edit in pairs(self.cfg.edits)do
  local raw=self:original(h);assert(D.hex(D.hash_resource(raw))==edit.expected,'package changed since editing: '..h)
  out[h]=M.package_bytes(raw,edit.entries)
 end
 if next(self.cfg.selected)and self.cfg.merge_enabled~=false then
  assert(next(self.cfg.targets),'select at least one merge target or clear the merge selection')
  local extra,packages=self:expand(self.cfg.selected)
  for h in pairs(self.cfg.targets)do
   local raw=out[h]or self:original(h);local entries=M.parse_package(raw)
   for _,e in ipairs(extra)do entries[#entries+1]=e end
   out[h]=M.package_bytes(raw,unique(entries))
  end
  self.report={packages=#packages,resources=#extra,targets=#keys(self.cfg.targets),status='GENERATED_NOT_LIVE_VERIFIED'}
 else self.report={packages=0,resources=0,targets=0,status='GENERATED_NOT_LIVE_VERIFIED'}end
 return out
end
function M:register_array(key,spec,baseline)
 self.arrays[key]={spec=spec,baseline=copy(baseline)}
 return self.cfg.arrays[key]and self.cfg.arrays[key].values or baseline
end
function M:array_values(key)
 return copy(self.cfg.arrays[key]and self.cfg.arrays[key].values or assert(self.arrays[key],'array unavailable').baseline)
end
-- Entity attachment arrays share the bounded LDLD serializer, but never the package catalogue.
function M:validate_array_value(spec,h)
 if not spec.domain or spec.domain=='package'then assert(self.catalog[h],'unknown package: '..h)
 elseif spec.domain=='modifier_entity'then
  assert(self.modifier_entities and self.modifier_entities[h],'unknown local modifier entity: '..h)
 else error('unsupported array reference domain: '..tostring(spec.domain))end
end
function M:set_array(key,values)
 local a=assert(self.arrays[key],'array unavailable');local list={}
 for _,h in ipairs(values)do h=M.hash(h);self:validate_array_value(a.spec,h);list[#list+1]=h end
 return self:mutate(function()self.cfg.arrays[key]={spec=copy(a.spec),expected=copy(a.baseline),values=list}end)
end
function M:append_selected(key)
 local values=self:array_values(key);local seen={};for _,h in ipairs(values)do seen[h]=true end
 for _,h in ipairs(keys(self.cfg.selected))do if not seen[h]then values[#values+1]=h;seen[h]=true end end
 return self:set_array(key,values)
end
function M:edit_array(key,index,text)
 local a=self:array_values(key)
 if text:match('^%s*[-]?%s*$')then assert(a[index],'no array item');table.remove(a,index)
 else assert(index>=1 and index<=#a+1,'invalid array index');a[index]=M.input_hash(text)end
 return self:set_array(key,a)
end
function M:reset(kind,key)
 return self:mutate(function()
  if kind=='all'then self.cfg.edits={};self.cfg.selected={};self.cfg.arrays={};self.cfg.targets={['18235E0C9EC0E636']=true};self.cfg.merge_enabled=true
  elseif kind=='package'then self.cfg.edits[key]=nil;self.cfg.selected[key]=nil;self.cfg.targets[key]=key=='18235E0C9EC0E636'and true or nil
  elseif kind=='array'then self.cfg.arrays[key]=nil
  elseif kind=='plan'then self.cfg.selected={};self.cfg.targets={['18235E0C9EC0E636']=true};self.cfg.merge_enabled=true end
 end)
end
function M:preset(action,key,slot,scope)
 local id=key..'/'..slot
 if action=='save'then return self:mutate(function()
  self.cfg.presets[id]=scope=='plan'and{selected=copy(self.cfg.selected),targets=copy(self.cfg.targets),merge_enabled=self.cfg.merge_enabled~=false}
   or scope=='array'and{array=copy(self.cfg.arrays[key]or false)}or{edit=copy(self.cfg.edits[key]or false),selected=self.cfg.selected[key]or false,target=self.cfg.targets[key]or false}
 end)end
 if action=='clear'then return self:mutate(function()self.cfg.presets[id]=nil end)end
 local saved=self.cfg.presets[id];if not saved then return nil,'No saved preload preset'end
 return self:mutate(function()
  if scope=='plan'then self.cfg.selected=copy(saved.selected);self.cfg.targets=copy(saved.targets);self.cfg.merge_enabled=saved.merge_enabled~=false
  elseif scope=='array'then self.cfg.arrays[key]=saved.array and copy(saved.array)or nil
  else self.cfg.edits[key]=saved.edit and copy(saved.edit)or nil;self.cfg.selected[key]=saved.selected or nil;self.cfg.targets[key]=saved.target or nil end
 end)
end
function M:snapshot()
 local snapshot={version=1}
 for _,key in ipairs({'edits','selected','targets','arrays'})do snapshot[key]=copy(self.cfg[key])end
 snapshot.merge_enabled=self.cfg.merge_enabled~=false
 return snapshot
end
function M:apply_snapshot(snapshot)
 if type(snapshot)~='table'or snapshot.version~=1 then return nil,'Unsupported preload preset'end
 for _,key in ipairs({'edits','selected','targets','arrays'})do if type(snapshot[key])~='table'then return nil,'Invalid preload section: '..key end end
 return self:mutate(function()
  for _,key in ipairs({'edits','selected','targets','arrays'})do self.cfg[key]=copy(snapshot[key])end
  self.cfg.merge_enabled=snapshot.merge_enabled~=false
 end)
end
function M:apply_legacy_preset(key,saved)
 if type(saved)~='table'then return nil,'Invalid legacy preload preset'end
 local original_key=key:match('^(.*)/%d+$');if not original_key then return nil,'Invalid legacy preload identity'end
 return self:mutate(function()
  if saved.selected and saved.targets then
   self.cfg.selected=copy(saved.selected);self.cfg.targets=copy(saved.targets);self.cfg.merge_enabled=saved.merge_enabled~=false
  elseif saved.array~=nil then
   self.cfg.arrays[original_key]=saved.array and copy(saved.array)or nil
  else
   assert(self.catalog[original_key],'Package is unavailable in this game build')
   self.cfg.edits[original_key]=saved.edit and copy(saved.edit)or nil
   self.cfg.selected[original_key]=saved.selected or nil;self.cfg.targets[original_key]=saved.target or nil
  end
 end)
end
-- Append array data inside its original LDLD block; old offsets stay valid and no other block is repointed.
function M:apply_arrays(changes,H,schemas)
 local groups={};for key,edit in pairs(self.cfg.arrays)do
  local s=edit.spec;assert(self.arrays[key],'saved array unavailable in this game build: '..key)
  for _,field in ipairs({'file','root','ordinal','offset','domain'})do assert(s[field]==self.arrays[key].spec[field],'saved array source differs from the verified source')end
  assert(type(edit.values)=='table'and #edit.values<=100000,'invalid array length')
  for _,value in ipairs(edit.values)do assert(type(value)=='string'and value==M.hash(value),'invalid saved array reference');self:validate_array_value(s,value)end
  if s.domain=='modifier_entity'then assert(require('modifier_assignments').check_array(s,schemas),'modifier attachment layout changed')
  else assert(require('preload_components').check_layout(s.root,schemas),'array layout changed')end
  groups[s.file]=groups[s.file]or{};groups[s.file][#groups[s.file]+1]=edit
 end
 for file,edits in pairs(groups)do
  local change;for _,c in ipairs(changes)do if c.name==file then change=c end end
  if not change then change=assert(H.snapshot(file));changes[#changes+1]=change end
  local bytes=ffi.string(change.plain,change.n);local hs=G.headers(change.plain,change.n)
  local counts,patches,matched={},{},{}
  for i,h in ipairs(hs)do
   counts[h.type]=(counts[h.type]or 0)+1
   local payload=bytes:sub(h.at+25,h.at+24+h.size);local additions={};local size=#payload
   for _,edit in ipairs(edits)do local s=edit.spec
    if s.root==h.type and s.ordinal==counts[h.type]then
     assert(s.offset+16<=#payload,'array descriptor outside block')
     local lo,hi,n=D.u32(payload,s.offset),D.u32(payload,s.offset+4),D.u32(payload,s.offset+8)
     assert(n<=100000 and(n==0 or hi==0 and lo+n*8<=#payload),'invalid serialized package array')
     local actual={};for j=0,n-1 do actual[#actual+1]=D.hex(payload:sub(lo+j*8+1,lo+j*8+8))end
     assert(table.concat(actual,',')==table.concat(edit.expected,','),'array changed outside preload editor')
     local at=size+(8-size%8)%8;local a={string.rep('\0',at-size)}
     for _,v in ipairs(edit.values)do a[#a+1]=D.unhex(v)end
     additions[#additions+1]=table.concat(a);size=at+#edit.values*8
     local pointer=#edit.values>0 and at or 0
     payload=payload:sub(1,s.offset)..D.p32(pointer)..D.p32(0)..D.p32(#edit.values)..D.p32(0)..payload:sub(s.offset+17)
     matched[edit]=true
    end
   end
   if #additions>0 then
    payload=payload..table.concat(additions)
    local header=bytes:sub(h.at+1,h.at+12)..D.p32(#payload)..bytes:sub(h.at+17,h.at+24)
    patches[i]=header..payload
   end
  end
  for _,e in ipairs(edits)do assert(matched[e],'array source block is absent')end
  local out={bytes:sub(1,hs[1].at)}
  for i,h in ipairs(hs)do
   local finish=i<#hs and hs[i+1].at or#bytes
   out[#out+1]=patches[i]or bytes:sub(h.at+1,h.at+24+h.size)
   out[#out+1]=bytes:sub(h.at+25+h.size,finish)
  end
  local raw=table.concat(out);local p=G.alloc(#raw);ffi.copy(p,raw,#raw);G.free(change.plain)
  change.plain,change.n,change.floats=p,#raw,{};change.bytes=change.bytes+1
 end
end
return M
