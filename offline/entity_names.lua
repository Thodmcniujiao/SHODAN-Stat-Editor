-- One JSON per entity group. The legacy catalog is only an import source.
local F=require('preset_files');local J=require('json_data');local IDs=require('name_ids')
local M={}
local function files(folder)
 local out={};for _,p in ipairs(F.list(folder))do if p:lower():match('%.json$')then out[#out+1]=p end end;return out
end
local function atomic(path,data)
 assert(F.write(path..'.new',J.encode(data,true)));assert(F.move(path..'.new',path))
end
local function localized(name)return type(name)=='table'and(name['zh-Hans']or name.en or select(2,next(name)))or name end
local function validate_name(name)
 if type(name)=='string'then assert(#name<=1024 and not name:find('[%z\1-\31]'),'invalid planning name');return end
 assert(type(name)=='table'and name~=J.null and next(name),'name must be text or a language map')
 for k,v in pairs(name)do assert(type(k)=='string'and type(v)=='string');validate_name(v)end
end
function M.load(folder)
 local cfg={version=1,default_category='other',categories={},entities={},rules={},by_id={},files={}}
 local paths=files(folder);assert(#paths>0,'EntityNames contains no group JSON')
 for order,path in ipairs(paths)do
  local raw=assert(F.read(folder..'/'..path),'Cannot read '..path)
  local t=J.decode(raw);assert(type(t)=='table'and t~=J.null,path..': expected object')
  local id=t.id or(path=='未分类.json'and'other')or('g'..path:gsub('.',function(c)return string.format('%02x',c:byte())end))
  assert(type(id)=='string'and id:match('^[%w_-]+$')and id~='all'and not cfg.by_id[id],path..': invalid/duplicate group id')
  local name=t.group or t.name or path:gsub('%.json$','');validate_name(name)
  local category={id=id,name=name,order=t.order or order};assert(type(category.order)=='number')
  cfg.categories[#cfg.categories+1]=category;cfg.by_id[id]=category;cfg.files[id]={path=folder..'/'..path,data=t}
  local rows=t.entities;assert(type(rows)=='table'and rows~=J.null,path..': entities must be an array or object')
  for key,item in pairs(rows)do
   if type(item)=='string'then item={hash=key,name=item}end
   assert(type(item)=='table'and item~=J.null,path..': invalid entity')
   local raw=item.hash or(type(key)=='string'and key);local hash=IDs.entity(raw)
   assert(hash,path..': invalid hash '..tostring(raw));validate_name(item.name)
   local kind=item.kind or(type(raw)=='string'and #raw==17 and raw:sub(1,1)=='U'and'unit')or'entity'
   assert(kind=='entity'or kind=='unit',path..': invalid entity kind')
   local rid=(kind=='unit'and'U'or'E')..hash
   assert(not cfg.entities[rid],path..': duplicate hash '..rid)
   cfg.entities[rid]={name=item.name,category=id}
  end
 end
 if not cfg.by_id.other then
  local group={version=1,id='other',group={en='Unclassified',['zh-Hans']='未分类'},order=1000,entities=J.array()}
  assert(not F.read(folder..'/未分类.json'),'未分类.json must use group id "other"')
  atomic(folder..'/未分类.json',group)
  return M.load(folder)
 end
 table.sort(cfg.categories,function(a,b)return a.order==b.order and a.id<b.id or a.order<b.order end)
 return cfg
end
function M.open(folder,legacy,records)
 assert(F.mkdir(folder),'Cannot create '..folder);local paths=files(folder)
 if #paths==0 then
  local groups={}
  for _,cat in ipairs(legacy.categories)do
   groups[cat.id]={version=1,id=cat.id,group=cat.id=='other'and{en='Unclassified',['zh-Hans']='未分类'}or cat.name,
    order=cat.order,entities=J.array()}
  end
  for _,r in ipairs(records)do
   local item=legacy.entities[r.id]or legacy.entities[r.hash]or{}
   groups[r.category].entities[#groups[r.category].entities+1]={hash='0x'..r.hash,name=item.name or r.base_name,kind=r.kind}
  end
  -- Retain user entries for entities absent from this game version.
  local seen={};for _,r in ipairs(records)do seen[r.id]=true;seen[r.hash]=true end
  for id,item in pairs(legacy.entities)do if not seen[id]then
   local group=groups[item.category or legacy.default_category]
   group.entities[#group.entities+1]={hash='0x'..assert(IDs.hex(id)),name=item.name or id,kind=id:sub(1,1)=='U'and'unit'or'entity'}
  end end
  for hash,name in pairs(legacy.hash_names or{})do
   local found=false
   for _,group in pairs(groups)do for _,item in ipairs(group.entities)do
    if IDs.hex(item.hash)==hash then
     local explicit=legacy.entities[(item.kind=='unit'and'U'or'E')..hash]or legacy.entities[hash]
     if not(explicit and explicit.name)then item.name=name end
     found=true
    end
   end end
   if not found then groups[legacy.default_category].entities[#groups[legacy.default_category].entities+1]={hash='0x'..hash,name=name}end
  end
  for id,group in pairs(groups)do
   local filename=(id=='other'and'未分类'or localized(group.group)):gsub('[<>:"/\\|?*]','_')
   -- Include the stable id to keep equal translated group names distinct.
   if id~='other'then filename=filename..' ('..id..')'end
   atomic(folder..'/'..filename..'.json',group)
  end
 end
 local cfg=M.load(folder);local extra=J.array()
 for _,r in ipairs(records)do if not cfg.entities[r.id]then extra[#extra+1]={hash='0x'..r.hash,name=r.base_name,kind=r.kind}end end
 if #extra>0 then
  local file=cfg.files.other;local rows=file.data.entities
  -- Normalize object-form unclassified files before appending newly discovered hashes.
  local all=J.array();for key,item in pairs(rows)do
   if type(item)=='string'then item={hash=key,name=item}else if not item.hash then item.hash=key end end
   all[#all+1]=item
  end
  for _,item in ipairs(extra)do all[#all+1]=item end
  file.data.entities=all;atomic(file.path,file.data);cfg=M.load(folder)
 end
 return cfg
end
return M
