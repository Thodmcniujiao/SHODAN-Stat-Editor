-- Shared entity directory and declarative, reloadable naming/classification.
local D=require('demolition');local J=require('json_data');local I=require('install');local N=require('entity_names');local IDs=require('name_ids')
local C={};C.__index=C
local Work=require('startup_work')
local here=(debug.getinfo(1,'S').source:match('^@(.*[/\\])')or'./')
-- the component pages, in order; the kinds with views of their own (c[kind]: health_ / drown_ / shield_components)
local KINDS={'health','demolition','drown','shield','throwable','thrower','minefield','mine_spawner','faction','mount','inventory','sensor_eye','turret','eagle','eagle_spawner'}
local VIEW={health=true,drown=true,shield=true,throwable=true,thrower=true,minefield=true,mine_spawner=true,faction=true,mount=true,inventory=true,sensor_eye=true,turret=true,eagle=true,eagle_spawner=true}
local SLOT={health='HealthComponents',demolition='DemolitionComponents',drown='DrownComponents',shield='ShieldComponents',
 throwable='ThrowableComponents',thrower='ThrowerComponents',minefield='MinefieldComponents',mine_spawner='MineSpawnerComponents',
 faction='FactionComponents',mount='MountComponents',inventory='InventoryComponents',
 sensor_eye='SensorEyeComponents',turret='TurretComponents',eagle='EagleComponents',eagle_spawner='EagleSpawnerComponents'}
-- the kinds built by component_view.lua (their pages: component_view = kind)
local GENERIC={throwable=true,thrower=true,minefield=true,mine_spawner=true,faction=true,mount=true,inventory=true,
 sensor_eye=true,turret=true,eagle=true,eagle_spawner=true}
-- Component kinds added by a build share the same deferred placeholder scheme.
local function available(self,r,kind)
 if kind=='demolition'then return r.destruction~=nil and r.destruction.index~=nil end
 local view=VIEW[kind]and self.context[kind]
 return view~=nil and r.kind=='entity'and view.by_entity[r.hash]~=nil
end
local function dh(s)local h=5381;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return(h-5381)%4294967296 end
local function label(v,lang)return type(v)=='table'and(v[lang]or v.en or v['zh-Hans']or next(v)and select(2,next(v)))or v end
local function text_name(v)
 if type(v)=='string'then assert(#v<=1024 and not v:find('[%z\1-\31]'),'invalid display name');return end
 assert(type(v)=='table'and v~=J.null and next(v),'name must be text or a language map')
 for k,s in pairs(v)do assert(type(k)=='string');text_name(s);assert(type(s)=='string')end
end
local function array(t,name)
 assert(type(t)=='table'and t~=J.null,name..' must be an array')
 local n=0
 for k in pairs(t)do assert(type(k)=='number'and k%1==0 and k>0,name..' must be an array');n=n+1 end
 assert(n==#t,name..' must be a dense array')
end
local function config(s)
 local t=J.decode(s);assert(type(t)=='table'and t.version==1,'entity_catalog version must be 1')
 assert(type(t.categories)=='table'and #t.categories>0,'categories must be a nonempty array')
 array(t.categories,'categories')
 local ids={}
 for i,c in ipairs(t.categories)do
  assert(type(c.id)=='string'and c.id:match('^[%w_-]+$')and c.id~='all'and not ids[c.id],'invalid/duplicate category id')
  text_name(c.name);c.order=c.order or i;assert(type(c.order)=='number');ids[c.id]=c
 end
 assert(ids[t.default_category],'default_category must name a defined category')
 t.rules=t.rules or{};array(t.rules,'rules')
 local allowed={category=true,path_prefix=true,path_contains=true,name_contains=true,hash_prefix=true,kind=true,component=true}
 for _,r in ipairs(t.rules)do
  assert(type(r)=='table'and ids[r.category],'rule category is undefined')
  for k,v in pairs(r)do assert(allowed[k]and type(v)=='string','invalid rule field: '..tostring(k))end
  assert(not r.kind or r.kind=='entity'or r.kind=='unit','rule kind must be entity or unit')
 end
 t.entities=t.entities or{};assert(type(t.entities)=='table'and t.entities~=J.null)
 local normalized={}
 for raw,e in pairs(t.entities)do
  local id=tostring(raw):gsub('^0[xX]',''):upper()
  assert(id:match('^[EU]?%x+$')and(#id==16 or #id==17 and id:sub(1,1):match('[EU]')),'invalid entity id: '..raw)
  assert(type(e)=='table'and e~=J.null,'entity metadata must be an object')
  assert(not e.category or ids[e.category],'entity category is undefined')
  if e.name then text_name(e.name)end
  for k in pairs(e)do assert(k=='name'or k=='category','invalid entity metadata field: '..tostring(k))end
  assert(not normalized[id],'duplicate normalized entity id');normalized[id]=e
 end
 t.entities=normalized;t.by_id=ids
 table.sort(t.categories,function(a,b)return a.order==b.order and a.id<b.id or a.order<b.order end)
 return t
end
local function collect(c)
 local records={}
 local function add(id,key,path)
  if not records[id]then records[id]={id=id,hash=D.hex(key),key=key,kind=id:sub(1,1)=='U'and'unit'or'entity',path=path or'',components={}}end
  return records[id]
 end
 local metadata=c.metadata or(c.bridge and c.bridge.panel.model)or{}
 local names=metadata.names or{}
 if metadata.entities and metadata.schemas then
  local groups=D.entity_blocks(metadata.entities)
  for _,b in ipairs(groups)do
   Work.checkpoint()
   local schema=metadata.schemas[b.type]
   if schema and #schema.members==2 then
    local map,array=schema.members[1],schema.members[2];local row=metadata.schemas[array.type]
    if map.atom==2 and array.atom==2 and row and map.count*16==map.size
     and map.offset+map.size<=b.size and array.offset+array.count*row.size<=b.size then
     for i=0,map.count-1 do
      local at=b.payload+map.offset+i*16;local key=metadata.entities:sub(at+1,at+8)
      if key~=string.rep('\0',8)and D.u32(metadata.entities,at+8)<array.count and D.u32(metadata.entities,at+12)==0 then
       local hash=D.hex(key);add('E'..hash,key,names[hash]).components[b.type]=true
      end
     end
    end
   end
  end
 end
 for hash,page in pairs(c.health.by_entity)do local r=add('E'..hash,page.key,page.path);if page.name~=hash then r.base_name=page.name end end
 for _,kind in ipairs(KINDS)do
  if VIEW[kind]and kind~='health'then
   for hash,page in pairs(c[kind]and c[kind].by_entity or{})do
    local r=add('E'..hash,page.key,page.path)
    if(not r.base_name or r.base_name==hash)and page.name~=hash then r.base_name=page.name end
    if page.catalog_hint then r.hint=page.catalog_hint end
   end
  end
 end
 local model=c.bridge and c.bridge.panel.model
 for _,t in ipairs(model and model.targets or{})do
  local r=add(t.id,t.entity_key or t.unit_key,t.path~=t.hash and t.path or names[t.hash]);r.destruction=t
  if not r.base_name and t.name~=t.hash then r.base_name=t.name end
 end
 local hints={Terminids='terminids',Automatons='automatons',Illuminate='illuminate',SEAF='seaf'}
 for _,w in ipairs(c.weapons)do
  local r=w.key and records['E'..D.hex(w.key)]
  if r and not w.record then r.base_name=r.base_name or w.name end
  if r and w.catalog_hint then r.hint=w.catalog_hint end
  for i,m in ipairs(w.enemy and w.enemy.members or{})do
   r=records['E'..D.hex(m.key)]
   if r then r.base_name=w.name..(#w.enemy.members>1 and(' · '..i)or'');r.hint=hints[w.slot]end
  end
 end
 local out={}
 for _,r in pairs(records)do
  r.base_name=r.base_name or(r.path~=''and r.path:match('([^/]+)$'))or r.hash
  out[#out+1]=r
 end
 table.sort(out,function(a,b)return a.id<b.id end)
 return out
end
local function matches(r,rule)
 local path=r.path:lower();local name=r.base_name:lower()
 return(not rule.path_prefix or path:sub(1,#rule.path_prefix)==rule.path_prefix:lower())
  and(not rule.path_contains or path:find(rule.path_contains:lower(),1,true))
  and(not rule.name_contains or name:find(rule.name_contains:lower(),1,true))
  and(not rule.hash_prefix or r.hash:sub(1,#rule.hash_prefix)==rule.hash_prefix:upper())
  and(not rule.kind or rule.kind==r.kind)
  and(not rule.component or r.components[dh(rule.component)])
end
local function make(self,c,r,kind)
 local views=VIEW[kind]and c[kind]
 local page=views and r.kind=='entity'and views.by_entity[r.hash]
 if not page then
  local namespace='shodan/components/'..kind..'/'..(VIEW[kind]and r.kind=='entity'and r.hash:lower()or r.id:lower())
  local hash=D.hex(D.hash_resource(namespace));assert(not c.by_hash[hash],'component view hash collision')
  page={hash=hash,key=r.key,rows={},by_id={},field_keys={},health_component=kind=='health',drown_component=kind=='drown',shield_component=kind=='shield',component_view=GENERIC[kind]and kind or nil,
   entity_hash=r.hash,slot=SLOT[kind]}
  c.by_hash[hash]=page
 end
 page.component_entry=true;page.component_kind=kind;page.entity_id=r.id;page.catalog_record=r;page.path=r.path
 page.has_component=VIEW[kind]and views and r.kind=='entity'and views.by_entity[r.hash]~=nil
  or kind=='demolition'and r.destruction~=nil and r.destruction.index~=nil
 page.has_component=page.has_component and true or false
 if kind=='demolition'and c.bridge then
  page.component_heading=function()return self:localized('DestructionSettings','破坏配置（DestructionSettings）')end
  for _,l in ipairs(c.bridge:rows(r.key,r.id))do
   local id=l.field.level.key;local row=c.add_row(page,'Destruction entry '..(l.level+1),id,
    l.hit and'Direct-hit threshold'or'Normal threshold','u32',{{id=id,field=l.field}},0,4294967295,10,100)
   local level,hit=l.level,l.hit
   row.demolition_level=level;row.demolition_inherited=l.field.level.inherited
   row.label_of=function()return self:localized(hit and'Direct-hit threshold'or'Normal threshold',hit and'直击拆毁阈值'or'普通拆毁阈值')end
   row.section=self:localized('Entry ','破坏记录 ')..(level+1)
   if l.field.level.inherited then row.note='Direct hits inherit Normal unless overridden' end
   page.field_keys[l.field.key]=true
  end
 end
 -- (a page whose rows are made when it is first shown has none yet: unavailable only without the component)
 page.component_unavailable=not page.has_component or(#page.rows==0 and not page.ensure_rows)
 local previous_note=page.note_of
 page.note='Entity '..r.hash
 page.note_of=function()
  if not page.has_component then return self:localized('This entity has no component/configuration for this page.','此实体没有本页对应的组件或配置，不能编辑。')..' · '..r.hash end
  if previous_note then return previous_note()end
  return 'DestructionSettings · '..r.hash..(r.destruction and(' · '..tostring(r.destruction.index))or'')
 end
 local views_list,by=rawget(self.views,kind),rawget(self.by_entity,kind)
 views_list[#views_list+1]=page;by[r.id]=page;self.all_views[#self.all_views+1]=page
 page.name=r.name or r.base_name;page.category=r.category
 return page
end
-- a lazy kind's pages, the first time it is used
function C:ensure(kind)
 if not self.lazy[kind]then return end
 self.lazy[kind]=nil
 rawset(self.views,kind,{});rawset(self.by_entity,kind,{})
 for _,r in ipairs(self.records)do make(self,self.context,r,kind)end
end
function C.build(c)
 for k,v in pairs(c.extra_views or{})do if c[k]==nil then c[k]=v end end
 for _,e in ipairs(c.extra_kinds or{})do
  if not VIEW[e.kind]then KINDS[#KINDS+1]=e.kind;VIEW[e.kind]=true;SLOT[e.kind]=e.slot;GENERIC[e.kind]=true end
 end
 local self=setmetatable({context=c,records=collect(c),views={},by_entity={},all_views={},revision=0,lazy={}},C)
 local function lazy_index(t,kind)if self.lazy[kind]then self:ensure(kind);return rawget(t,kind)end end
 setmetatable(self.views,{__index=lazy_index});setmetatable(self.by_entity,{__index=lazy_index})
 for _,kind in ipairs(KINDS)do
  -- Destruction pages own old saved values; all other kinds already have their
  -- real component pages registered. Gray placeholders can wait until selection.
  if kind~='demolition'then self.lazy[kind]=true else rawset(self.views,kind,{});rawset(self.by_entity,kind,{})end
 end
 local meta=c.metadata or{};self.path=meta.config_path or(I.home..'/entity_catalog.json')
 self.default_path=meta.default_path or(here..'entity_catalog.default.json')
 for _,r in ipairs(self.records)do
  Work.checkpoint()
  for _,kind in ipairs(KINDS)do
   if not self.lazy[kind]then make(self,c,r,kind)end
  end
 end
 local initial=I.read(self.path)
 if not initial then
  initial=assert(I.read(self.default_path),'missing default entity catalog JSON')
  local f=io.open(self.path,'wb');if f then f:write(initial);f:close()end
 end
 local ok,t=pcall(config,initial)
 if not ok then self.config_error=t;t=config(assert(I.read(self.default_path)))end
 self.config=t;self:refresh(true)
 self.folder=meta.names_folder or(self.path:match('^(.*)[/\\]')..'/EntityNames')
 local R=require('record_names')
 local names_dir=rawget(_G,'SHODAN_NAMES_DIRECTORY')
 if not R.loaded then pcall(R.load,self.path:match('^(.*)[/\\]'),names_dir)end
 t.hash_names=R.hash_names
 local named,folder_config=pcall(self.config_error and N.load or N.open,self.folder,t,self.records)
 if named then self.config=folder_config;self.config_error=nil;self:refresh(true)else self.config_error=folder_config end
 self:export_index()
 return self
end
function C:localized(en,zh)
 local lang=self.context.lang();return(lang=='zh-Hans'or lang=='zh-Hant')and zh or en
end
function C:refresh(force)
 local lang=self.context.lang();if not force and self.language==lang then return end;self.language=lang;self.cache={}
 for _,r in ipairs(self.records)do
  Work.checkpoint()
  local item=self.config.entities[r.id]or self.config.entities[r.hash]or{}
  local category=item.category
  if not category then for _,rule in ipairs(self.config.rules)do if matches(r,rule)then category=rule.category;break end end end
  r.category=category or(self.config.by_id[r.hint]and r.hint)or self.config.default_category
  r.category_name=label(self.config.by_id[r.category].name,lang)
  r.name=item.name and label(item.name,lang)or r.base_name
  r.decimal=r.decimal or IDs.decimal(r.hash)
  for _,kind in ipairs(KINDS)do
   local page=not self.lazy[kind]and self.by_entity[kind][r.id]
   if page then page.name=r.name;page.category=r.category end
   if kind=='demolition'and page then for _,row in ipairs(page.rows)do
    row.section=self:localized('Entry ','破坏记录 ')..(row.demolition_level+1)
    if row.demolition_inherited then row.note=self:localized('Direct hits inherit Normal unless overridden','未单独覆盖时，直击阈值继承普通命中')end
   end end
  end
 end
 self.revision=self.revision+1
end
function C:reload()
 local ok,t=pcall(N.open,self.folder,self.config,self.records)
 if not ok then self.config_error=t;return nil,t end
 self.config=t;self.config_error=nil;self:refresh(true);self:export_index(true);return true
end
function C:list(kind,category,show_missing,search,tr)
 self:refresh();local words={};for word in (search or''):lower():gmatch('%S+')do words[#words+1]=word end
 local cache_key=table.concat({kind,category or'all',tostring(show_missing),search or'',self.language},'|')
 if self.cache[cache_key]then return self.cache[cache_key]end
 local out={}
 for _,page in ipairs(self.views[kind])do
  local r=page.catalog_record
  local include=#words>0 or((show_missing or page.has_component)and(category==nil or category=='all'or category==r.category))
  local names=self.config.entities[r.id]or self.config.entities[r.hash];local aliases={}
  if names and type(names.name)=='table'then for _,v in pairs(names.name)do aliases[#aliases+1]=v end end
  local hay=((tr and tr(page.name)or page.name)..' '..r.base_name..' 0x'..r.hash..' '..r.decimal..' '..r.path..' '..r.category_name..' '..table.concat(aliases,' ')):lower()
  for _,w in ipairs(words)do if not hay:find(w,1,true)then include=false;break end end
  if include then out[#out+1]=page end
 end
 table.sort(out,function(a,b)
  if a.category~=b.category then local ca,cb=self.config.by_id[a.category],self.config.by_id[b.category]
   return ca.order==cb.order and ca.id<cb.id or ca.order<cb.order end
  if a.name==b.name then return a.entity_id<b.entity_id end;return a.name:lower()<b.name:lower()
 end)
 self.cache[cache_key]=out;return out
end
function C:categories()
 self:refresh();local out={{id='all',name=self:localized('All categories','全部分类')}}
 for _,c in ipairs(self.config.categories)do out[#out+1]={id=c.id,name=label(c.name,self.language)}end;return out
end
function C:export_index(force)
 local path=self.path:match('%.json$')and self.path:gsub('%.json$','.index.json')or(self.path..'.index.json')
 local stamp_path=path..'.stamp'
 -- Hash the actual exported inputs, including all membership flags. No game-file
 -- offsets or stale decoded data are reused by this cache.
 local fingerprint={'entity-index-v2',table.concat(KINDS,':')}
 for _,r in ipairs(self.records)do
  Work.checkpoint()
  local components={};for typ in pairs(r.components)do components[#components+1]=string.format('%08X',typ)end;table.sort(components)
  for _,value in ipairs({r.id,r.hash,r.kind,r.name,r.path,r.category,table.concat(components,',')})do
   fingerprint[#fingerprint+1]=#value..':'..value
  end
  local flags={};for _,kind in ipairs(KINDS)do flags[#flags+1]=available(self,r,kind)and'1'or'0'end
  fingerprint[#fingerprint+1]=table.concat(flags)
 end
 local signature=D.hex(D.hash_resource(table.concat(fingerprint,'|')))
 if not force and I.read(stamp_path)==signature then
  local current=io.open(path,'rb');if current then local size=current:seek('end');current:close();if size and size>0 then return false end end
 end
 local rows=J.array()
 for _,r in ipairs(self.records)do
  Work.checkpoint()
  local components=J.array();for typ in pairs(r.components)do components[#components+1]=string.format('%08X',typ)end;table.sort(components)
  rows[#rows+1]={id=r.id,hash=r.hash,kind=r.kind,name=r.name,path=r.path,category=r.category,components=components,
  }
  for _,kind in ipairs(KINDS)do
   rows[#rows][kind]=available(self,r,kind)and true or false
  end
 end
 local f=io.open(path..'.new','wb')
 if f then
  local ok=f:write(J.encode({version=1,entities=rows}));f:close()
  if ok and I.move_file(path..'.new',path,9)~=0 then
   local stamp=io.open(stamp_path..'.new','wb')
   if stamp then local saved=stamp:write(signature);stamp:close();if saved then I.move_file(stamp_path..'.new',stamp_path,9)end end
   return true
  end
 end
end
return C
