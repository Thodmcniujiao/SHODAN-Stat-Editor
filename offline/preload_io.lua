local I=require('install')
local D=require('demolition')
local UA=require('unit_aliases')
local DATA=require('preload_data')
local S=require('preload_store')
local M={};M.__index=M
function M.new(options)return setmetatable({options=options},M)end
-- The game's package manifests: read straight out of its archives (archives.lua; the catalog names the archives
-- holding each package), or (o.raw: the tests' fixtures; o.filediver: asked for) a folder of exported ones.
function M:load_index()
 if self.paths or self.store then return end
 local o=self.options;local folder=o.raw
 if not folder and not o.filediver then
  local A=require('archives')
  local root=o.game:gsub('\\','/'):gsub('/+$',''):gsub('/[Gg][Aa][Mm][Ee]$','')
  self.store=A.open(root);return
 end
 if not folder then
  local cache=UA.cache_dir(I.home,o.game,o.owned());self.export_cache=cache;I.mkdirs(cache)
  folder=cache..'/preload-packages';I.mkdirs(folder)
  local logpath=cache..'/preload-packages.log'
  local game=o.game:gsub('\\','/'):gsub('/data/game/?$','')
  local exe=assert(UA.find_filediver(o.here),'Filediver not found; set filediver path.txt in the settings folder')
  UA.run_jobs(exe,{{args={'--gamedir',game,'--no-pager','--types','package','--include','*','--text-format','raw',
   '--raw-format','separate','--out',folder},label='preload package manifests',logpath=logpath,done=logpath..'.ok'}},o)
 end
 local paths={}
 for _,p in ipairs(UA.walk(folder))do
  local rel=p:sub(#folder+2):gsub('\\','/'):match('^(.-)%.package%.main$')
  if rel then local h=rel:match('^0x(%x+)$');h=h and h:upper()or D.hex(D.hash_resource(rel));paths[h]=p end
 end
 assert(next(paths),'No package manifests were exported')
 self.paths=paths
end
function M:load(h)
 self:load_index()
 local s
 if self.store then
  local A=require('archives');local entry=assert(DATA.catalog[h],'Package not in the catalog: '..h)
  for _,id in ipairs(entry.archives)do
   local ok,r=pcall(self.store.resource,self.store,id:lower(),A.raw(h)..A.raw(S.PTYPE))
   if ok and r then s=r.main;break end
  end
  assert(s,'Package not found in the game archives: '..h)
 else
  local p=assert(self.paths[h],'Package not found in current game export: '..h)
  s=assert(I.read(p),'Could not read package '..h)
 end
 -- Filediver extracts bundle originals; ordinary triad patches must be overlaid explicitly.
 self.patch_cache=self.patch_cache or{};self.patch_lists=self.patch_lists or{}
 self.owner_set=self.owner_set or self.options.owned()
 local root=self.options.game:gsub('\\','/'):gsub('/game/?$','')
 for _,id in ipairs(assert(DATA.catalog[h]).archives)do
  local list=self.patch_lists[id]
  if not list then
   list={};for _,name in ipairs(I.list_files(root,id..'.patch_*'))do if name:match('%.patch_%d+$')and not self.owner_set[name]then list[#list+1]=name end end
   table.sort(list,function(a,b)return tonumber(a:match('%.patch_(%d+)$'))<tonumber(b:match('%.patch_(%d+)$'))end);self.patch_lists[id]=list
  end
  for _,name in ipairs(list)do
   if not self.patch_cache[name]then self.patch_cache[name]=UA.read_archive(assert(I.read(root..'/'..name)),I.read(root..'/'..name..'.gpu_resources'),I.read(root..'/'..name..'.stream'))end
   local r=self.patch_cache[name][D.unhex(h)..D.unhex(S.PTYPE)];if r then s=r.main end
  end
 end
 S.parse_package(s);return s
end
function M:prepare(model,existing,aliases)
 if self.export_cache and self.export_cache~=UA.cache_dir(I.home,self.options.game,self.options.owned())then self.paths=nil end
 self.store=nil   -- (the archives read again: a game update since the last install)
 self.patch_cache,self.patch_lists,self.owner_set={},{},self.options.owned()
 local outputs=model:package_outputs();if not next(outputs)then return existing,{}end
 local o=self.options;local root=o.game:gsub('\\','/'):gsub('/game/?$','')
 local owned=o.owned();local archives={};local writes={};for k,v in pairs(existing)do writes[k]=v end
 for name,main in pairs(existing)do if name:match('%.patch_%d+$')then
  local id=name:match('^(%x+)%.patch_');archives[id]={name=name,resources=UA.read_archive(main,existing[name..'.gpu_resources'],existing[name..'.stream'])}
 end end
 local function source(id)
  if archives[id]then return archives[id]end
  assert(id:match('^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$'),'invalid package source archive')
  local max=-1
  for _,name in ipairs(I.list_files(root,id..'.patch_*'))do
   local n=tonumber(name:match('%.patch_(%d+)$'));if n and not owned[name]then max=math.max(max,n)end
  end
  local name
  for old in pairs(owned)do local n=tonumber(old:match('^'..id..'%.patch_(%d+)$'));if n and n>max then name=old;break end end
  if not name then
   local n=max+1
   repeat name=id..'.patch_'..n;n=n+1 until not I.exists(root..'/'..name)and not I.exists(root..'/'..name..'.gpu_resources')and not I.exists(root..'/'..name..'.stream')
  end
  archives[id]={name=name,resources={}};return archives[id]
 end
 local aliasmap={}
 for _,a in ipairs(aliases or{})do
  local src=D.unhex(a.source_unit);aliasmap[src]=aliasmap[src]or{};aliasmap[src][#aliasmap[src]+1]=D.unhex(a.alias_unit)
 end
 local report={}
 for h,raw in pairs(outputs)do
  local p=assert(DATA.catalog[h]);assert(#p.archives>0,'No archive location for package '..h)
  if next(aliasmap)then raw=UA.patch_package(raw,aliasmap)or raw end
  for _,id in ipairs(p.archives)do
   local arc=source(id:lower());local name,typ=D.unhex(h),D.unhex(S.PTYPE)
   arc.resources[name..typ]={name=name,type=typ,main=raw}
   report[#report+1]={package=h,archive=id,entries=#S.parse_package(raw)}
  end
 end
 for _,arc in pairs(archives)do
  local resources={};for _,r in pairs(arc.resources)do resources[#resources+1]=r end
  local bytes=UA.archive(resources);local back=UA.read_archive(bytes.main,bytes.gpu,bytes.stream)
  for k,r in pairs(arc.resources)do assert(back[k]and back[k].main==r.main and back[k].gpu==(r.gpu or'')and back[k].stream==(r.stream or''),'package patch read-back differs')end
  writes[arc.name]=bytes.main
  writes[arc.name..'.gpu_resources']=#bytes.gpu>0 and bytes.gpu or nil
  writes[arc.name..'.stream']=#bytes.stream>0 and bytes.stream or nil
 end
 return writes,report
end
return M
