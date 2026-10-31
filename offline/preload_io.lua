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
 -- Empty or array-only plans do not request package I/O. Existing unit-alias
 -- outputs still pass through; the install transaction removes obsolete patches.
 if not next(model.cfg.edits)and not(next(model.cfg.selected)and model.cfg.merge_enabled~=false)then
  model.report={packages=0,resources=0,targets=0,status='GENERATED_NOT_LIVE_VERIFIED'}
  return existing,{}
 end
 if self.export_cache and self.export_cache~=UA.cache_dir(I.home,self.options.game,self.options.owned())then self.paths=nil end
 self.store=nil   -- (the archives read again: a game update since the last install)
 self.patch_cache,self.patch_lists,self.owner_set={},{},self.options.owned()
 self:load_index()
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
 local outputs={}
 if not self.store then
  outputs=model:package_outputs()
  if not next(outputs)then return existing,{}end
 else
  local A=require('archives')
  for h,edit in pairs(model.cfg.edits)do
   local raw=model:original(h);assert(D.hex(D.hash_resource(raw))==edit.expected,'package changed since editing: '..h)
   outputs[h]=S.package_bytes(raw,edit.entries)
  end
  local target_donors={}
  local selected_count=#S.keys(model.cfg.selected)
  -- Large explicit selections use the environment package arrays. Small
  -- explicit selections also bundle their resources into the chosen targets.
  local bundle_donors=(selected_count>0 and selected_count<=16 and model.cfg.merge_enabled~=false)
   and model:effective_selected()or{}
  if #bundle_donors>0 then
   local targets=next(model.cfg.targets)and model.cfg.targets or{['18235E0C9EC0E636']=true}
   for th in pairs(targets)do target_donors[th]=bundle_donors end
  end
  local MAX_PATCH_BYTES=192*1024*1024
  local total_res=0
  for th,donors in pairs(target_donors)do
   local t_id=th:lower()
   if self.store:has(t_id)then
    local base_dir=self.store:directory(t_id)
    local t_arc=source(t_id)
    local added_bytes=0
    for _,r in pairs(t_arc.resources)do added_bytes=added_bytes+#(r.main or'')+#(r.gpu or'')+#(r.stream or'')end
    local backed={}
    for _,d in ipairs(donors)do
     local d_id=d:lower()
     if d~=th and self.store:has(d_id)then
      local ok_dir,d_dir=pcall(self.store.directory,self.store,d_id)
      if ok_dir and d_dir then
       local d_need=0
       for _,f in ipairs(d_dir)do
        if A.hex(f.type)~=S.PTYPE and not base_dir.by[f.name..f.type]and not t_arc.resources[f.name..f.type]then
         d_need=d_need+f.main[2]+f.gpu[2]+f.stream[2]
        end
       end
       if added_bytes+d_need<=MAX_PATCH_BYTES then
        for _,f in ipairs(d_dir)do
         local t_hex,n_hex=A.hex(f.type),A.hex(f.name)
         if t_hex~=S.PTYPE then
          local k=f.name..f.type
          if base_dir.by[k]or t_arc.resources[k]then
           backed[#backed+1]={type=t_hex,name=n_hex}
          else
           local r=self.store:resource(d_id,k)
           if r then
            t_arc.resources[k]={name=f.name,type=f.type,main=r.main,gpu=r.gpu,stream=r.stream}
            added_bytes=added_bytes+#r.main+#r.gpu+#r.stream
            backed[#backed+1]={type=t_hex,name=n_hex}
           end
          end
         end
        end
        if self.options.pump then self.options.pump()end
       end
      end
     end
    end
    if next(t_arc.resources)==nil and not existing[t_arc.name]then archives[t_id]=nil end
    if #backed>0 then
     local raw=outputs[th]or model:original(th)
     local entries=S.parse_package(raw)
     for _,e in ipairs(backed)do entries[#entries+1]=e end
     local uniq=S.unique(entries)
     outputs[th]=S.package_bytes(raw,uniq)
     total_res=total_res+#backed
    end
   end
  end
  model.report={packages=#(model:effective_selected()),resources=total_res,targets=#S.keys(target_donors),status='GENERATED_WITH_RESOURCE_BUNDLES'}
  if not next(outputs)and not next(archives)then return existing,{}end
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
 for id,arc in pairs(archives)do
  local resources={};for _,r in pairs(arc.resources)do resources[#resources+1]=r end
  if #resources>0 then
   local bytes=UA.archive(resources);local back=UA.read_archive(bytes.main,bytes.gpu,bytes.stream)
   for k,r in pairs(arc.resources)do assert(back[k]and back[k].main==r.main and back[k].gpu==(r.gpu or'')and back[k].stream==(r.stream or''),'package patch read-back differs')end
   writes[arc.name]=bytes.main
   writes[arc.name..'.gpu_resources']=#bytes.gpu>0 and bytes.gpu or nil
   writes[arc.name..'.stream']=#bytes.stream>0 and bytes.stream or nil
  end
 end
 return writes,report
end
return M
