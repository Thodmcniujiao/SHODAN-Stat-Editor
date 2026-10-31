-- Current local package declarations. Runtime hot-join triggers are reference metadata only.
local V=require('component_view')
local D=require('demolition')
local DATA=require('preload_data')
local M={data=DATA,pages={},lists={},labels={
 PreloadExtra={'Extra preload','额外预载','額外預載'},
 PreloadGlobal={'Global / mission','全局／任务','全域／任務'},PreloadLoadout={'Loadout','装备包','裝備包'},
 PreloadEnemy={'Enemies','敌人包','敵人包'},PreloadWorld={'World','环境／星球','環境／星球'},
 PreloadCatalog={'Catalog','包目录','包目錄'},PreloadHotjoin={'Hot join','热加入参考','熱加入參考'},
}}
local R=V.R
M.root_labels={EnvironmentSettings={'Environment','环境','環境'},LevelGenerationPlanetData={'Planet','星球','星球'},
 GenerationRegionGroup={'Region','区域','區域'},SolarSystemSettings={'Solar system','星系','星系'},
 PlanetOverrideSettings={'Planet overrides','星球覆盖','星球覆寫'},GalacticPresenceSettings={'Galactic presence','银河表现','銀河表現'},
 StratagemSettings={'Stratagems','战备','戰備'},HelldiverCustomizationKit={'Armor','护甲','護甲'},
 DistantWarEffectPool={'Distant war','远景战争','遠景戰爭'}}
function M.translate_name(text,lang)
 if text=='Additional package preload'then return V.pick(lang,{'Additional package preload','额外资源包预载','額外資源包預載'})end
 local root,name=text:match('^(%w+) · (.*)$')
 local labels=root and M.root_labels[root]
 if labels then return V.pick(lang,labels)..' · '..name end
end
M.LOADOUT=0x7A858691
-- djb2 hashes use the game's subtract-5381 variant, as the installed type library does.
local function typehash(s)local h=5381;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return(h-5381)%4294967296 end
M.ENEMY=typehash('EnemyPackageComponentData');M.ENTITY_TYPES={[M.LOADOUT]=true,[M.ENEMY]=true}
M.SPECS={
 V.prepare({TYPE='LoadoutPackageComponentData',KEY='loadout_package',HASH=M.LOADOUT,SIZE=32,
  SLOT='PreloadLoadout',FLAG='preload_component',COMPONENT={'Loadout package component','装备加载组件','裝備載入組件'},
  GROUPS={{'package','Package and generation settings','资源包与生成设置','資源包與產生設定'}},
  LAYOUT={{0,4},{8,8},{16,8},{24,1},{25,1}},FIELDS={
   {'bundle_tag',0,'u32','package','Bundle tag (build time)','打包标签（构建时）','打包標籤（建置時）',R.hash,{note={'No runtime effect in the shipped schema.','旧版结构说明明确标注无运行时效果。','舊版結構說明明確標註無執行階段效果。'}}},
   {'package',8,'u64','package','Loadout package','装备资源包（package）','裝備資源包（package）',R.hash},
   {'audio_resource',16,'u64','package','Audio resource','音频资源（audio_resource）','音訊資源（audio_resource）',R.hash},
   {'include_default_customizations',24,'flag','package','Include default customizations (build time)','包含默认定制（构建时）','包含預設定製（建置時）',R.flag},
   {'unknown_0x19',25,'u8','package','Unknown byte +0x19','未知字节 +0x19','未知位元組 +0x19',R.u8},
  }}),
 V.prepare({TYPE='EnemyPackageComponentData',KEY='enemy_package',HASH=M.ENEMY,SIZE=32,
  SLOT='PreloadEnemy',FLAG='preload_component',COMPONENT={'Enemy package component','敌人加载组件','敵人載入組件'},
  GROUPS={{'package','Package and dependencies','资源包与依赖','資源包與相依項目'}},
  LAYOUT={{0,4},{8,8},{16,8},{24,8}},FIELDS={
   {'bundle_tag',0,'u32','package','Bundle tag (build time)','打包标签（构建时）','打包標籤（建置時）',R.hash,{note={'No runtime effect in the shipped schema.','旧版结构说明明确标注无运行时效果。','舊版結構說明明確標註無執行階段效果。'}}},
   {'package',8,'u64','package','Enemy package','敌人资源包（package）','敵人資源包（package）',R.hash},
   {'dependant_package',16,'u64','package','Dependent package','依赖资源包（dependant_package）','相依資源包（dependant_package）',R.hash},
   {'audio_resource',24,'u64','package','Audio resource','音频资源（audio_resource）','音訊資源（audio_resource）',R.hash},
  }}),
}
local function u32(b,o)
 if o<0 or o+4>#b then return end
 local a,c,d,e=b:byte(o+1,o+4);return a+c*256+d*65536+e*16777216
end
function M.hash_input(text)
 text=tostring(text):match('^%s*(.-)%s*$')
 local h=text:match('^0[xX](%x+)$')or(#text==16 and text:find('[a-fA-F]')and text:match('^%x+$'))
 if not h then for hash,p in pairs(DATA.catalog)do if p.path~=''and p.path==text then h=hash;break end end end
 if h and #h<=16 then
  h=string.rep('0',16-#h)..h
  return require('stratagem_components').u64_text(tonumber(h:sub(9),16),tonumber(h:sub(1,8),16))
 end
 return text
end
local function pointer(b,o,address)
 local lo,hi=u32(b,o),u32(b,o+4);if not hi then return end
 local v=lo+hi*4294967296
 if v>=#b and address then v=v-address end
 if v<0 or v>=#b then return end;return v
end
local function string_at(b,o,address)
 local p=pointer(b,o,address);if not p then return end
 local s=b:sub(p+1,p+257):match('^([^%z]*)%z')
 if s and #s>0 and not s:find('[%c]')then return s end
end
function M.identity(b,root,address)
 local t=DATA.schemas[root];local names={}
 for _,m in ipairs(t.members)do if m.storage==18 and m.atom==0 then
  local s=string_at(b,m.offset,address);if s then names[#names+1]=s end
 end end
 if #names>0 then return table.concat(names,' · ')end
 if root==0x08C2B982 then return D.hex(D.hash_resource(b:sub(9,32)))end
 return string.format('%08X%08X',u32(b,4)or 0,u32(b,0)or 0)
end
function M.check_layout(root,schemas,seen)
 seen=seen or{};if seen[root]then return true end;seen[root]=true
 local a,b=DATA.schemas[root],schemas and schemas[root]
 if not a or not b or a.size~=b.size or #a.members~=#b.members then return false end
 for i,m in ipairs(a.members)do
  local n=b.members[i]
  for _,k in ipairs({'offset','size','type','atom','storage','count'})do if m[k]~=n[k]then return false end end
  if(m.storage==19 or m.storage==20)and DATA.schemas[m.type]and not M.check_layout(m.type,schemas,seen)then return false end
 end
 return true
end
-- Follow only type-library members; pointers stay offsets in these host buffers except the existing stratagem table.
-- A rejected non-empty array disables the group, rather than exposing a partially parsed editable page.
function M.parse(b,root,address)
 local index={fields={},arrays={},identity=M.identity(b,root,address)}
 local seen={};local failure
 local function walk(tid,pos,path,depth)
  local t=DATA.schemas[tid];local key=tid..':'..pos
  if depth>24 or seen[key]then return end;seen[key]=true
  if not t or pos<0 or pos+t.size>#b then failure='record bounds';return end
  for _,m in ipairs(t.members)do
   local off=pos+m.offset;local meta=(DATA.fields[tid]or{})[m.offset]
   local label=string.format('%s+0x%X',path,m.offset)
   if m.storage==19 and DATA.schemas[m.type]then
    local p=pointer(b,off,address);if p and p~=0 then walk(m.type,p,label..'->',depth+1)end
   else
    local n=m.atom==2 and m.count or 1;local target=off
    local step=m.atom==2 and m.size/math.max(1,n)or m.size
    if m.atom==1 then
     n=u32(b,off+8);local pad=u32(b,off+12)
     step=m.storage==20 and DATA.schemas[m.type]and DATA.schemas[m.type].size or({[7]=8,[6]=4,[8]=4,[16]=4,[18]=8})[m.storage]
     if meta then index.arrays[#index.arrays+1]={offset=off,count=n or 0,label=label,alias=meta.alias,target=pointer(b,off,address)or 0}end
     if not n or n>100000 or pad~=0 then failure='array header';return end
     if n>0 then target=pointer(b,off,address)
      if not target or not step or target+n*step>#b then failure='array bounds';return end
     end
    end
    if step then for i=0,n-1 do
     local at=target+i*step;local p=label..((m.atom==1 or m.atom==2)and('['..i..']')or'')
     if m.storage==20 then walk(m.type,at,p..'.',depth+1)
     elseif m.storage==7 and meta then
      if at+8>#b then failure='hash bounds';return end
      index.fields[#index.fields+1]={offset=at,label=p,alias=meta.alias,inferred=meta.inferred,array_offset=m.atom==1 and off or nil}
     end
    end end
   end
  end
 end
 walk(root,0,'',0)
 if failure then return nil,failure end
 return index,#index.fields
end
function M.register(kinds)
 for _,s in ipairs(M.SPECS)do kinds[s.HASH]={name=s.KEY,stride=s.SIZE,keyed=true}end
 for _,r in ipairs(DATA.roots)do
  M.lists[r.hash]={}
  if not kinds[r.hash]then
   kinds[r.hash]={name='preload '..r.name,stride=1,groups=true,list=M.lists[r.hash],
    group_key=function(b,address)return 'preload '..r.hash..' '..(M.location(address)or M.identity(b,r.hash))end,
    parse=function(b,_,__,address)return M.parse(b,r.hash,address and address+24)end}
  end
 end
end
-- DL files may contain several distinct records with the same display name (or no name).
-- The source block ordinal is stable across value edits and must be part of their identity.
function M.location(address)
 if not M.locations then
  M.locations={}
  local ffi=require('ffi');local G=require('gamedata')
  for name,f in pairs(require('hostdata').files)do
   local counts={};local base=tonumber(ffi.cast('uintptr_t',f.p))
   for _,h in ipairs(G.headers(f.p,f.n))do
    counts[h.type]=(counts[h.type]or 0)+1
    M.locations[base+h.at]=name..'#'..h.type..':'..counts[h.type]
   end
  end
 end
 return M.locations[address]
end
function M.clear(kinds)
 M.locations=nil
 for _,r in ipairs(DATA.roots)do if kinds[r.hash]and kinds[r.hash].name=='preload '..r.name then kinds[r.hash].list={}end end
end
function M.protected_offsets(root,b,address)
 if not DATA.schemas[root]then return{}end
 local idx=M.parse(b,root,address);local out={}
 if idx then for _,f in ipairs(idx.fields)do out[f.offset]=true;out[f.offset+4]=true end end
 return out
end
function M.build(c)
 for _,list in pairs(M.pages)do for _,p in ipairs(list)do if c.by_hash[p.hash]==p then c.by_hash[p.hash]=nil end end end
 M.pages={PreloadGlobal={},PreloadLoadout={},PreloadEnemy={},PreloadWorld={},PreloadCatalog={},PreloadHotjoin={}}
 local owners={}
 for _,p in pairs(c.by_hash)do for _,r in ipairs(p.rows or{})do for _,part in ipairs(r.parts or{})do
  if not owners[part.field.key]then owners[part.field.key]={weapon=p,part=part}end
 end end end
 local function tx(t)return V.pick(c.lang(),t)end
 local function page(name,slot,key)
  local hash=D.hex(D.hash_resource('shodan/preload/'..slot..'/'..key))
  assert(not c.by_hash[hash],'preload page identity collision: '..key)
  local p={name=name,slot=slot,hash=hash,rows={},by_id={},field_keys={},preload_parameters=true,search=name..' '..key}
  c.by_hash[hash]=p;M.pages[slot][#M.pages[slot]+1]=p;return p
 end
 local function readonly(p,id,label,value,section)
  local row={id=id,label=type(label)=='table'and label[1]or label,storage='u32',parts={},empty=true,readonly_text=value,section=section or'Metadata'}
  if type(label)=='table'then row.label_of=function()return tx(label)end end
  row.section_of=function()return tx(section=='Packages'and{'Packages','资源包','資源包'}or{'Metadata','元数据','中繼資料'})end
  row.tip_of=function()return{row.label_of and row.label_of()or label,type(value)=='function'and value()or tostring(value)}end
  p.rows[#p.rows+1]=row;return row
 end
 local function package_row(p,row)
  local old=row.tip_of
  local function name()
   local lo,hi=c.read(row.parts[1].field),c.read(row.parts[2].field)
   local h=lo and hi and string.format('%08X%08X',hi,lo)or''
   local pkg=DATA.catalog[h]
   return pkg and(pkg.path~=''and pkg.path or(pkg.label and(pkg.label..' (0x'..h..')'))or'0x'..h)or h=='0000000000000000'and tx({'None','无','無'})or('0x'..h)
  end
  row.tip_of=function()local lines=old and old()or{};lines[#lines+1]=name();return lines end
  local info=readonly(p,row.id..'_resolved',{'Package path','资源包路径','資源包路徑'},name,row.section)
  info.component,info.component_of=row.component,row.component_of
  if row.section_of then info.section_of=row.section_of end
  p.search=p.search..' '..name()
 end
 M.entity_packages={}
 for _,spec in ipairs(M.SPECS)do
  if V.check_layout(spec,c.schemas,spec.HASH)and M.check_layout(typehash(spec.TYPE:gsub('Data$','')),c.schemas)then
   local view=V.build(spec,{table=c.tables[spec.HASH],kind=spec.HASH,weapons=c.weapons,by_hash=c.by_hash,
    field_at=c.field_at,read=c.read,add_row=c.add_row,default_of=c.default_of,schemas=c.schemas,names=c.names,lang=c.lang,log=c.log})
   for _,p in ipairs(view.pages)do
    p.preload_parameters=true;p.preload_order=1;p.search=p.name..' '..p.entity_hash
    local epath=(c.names or{})[p.entity_hash]or''
    local fac=epath:find('fac_bugs')and'bug'or epath:find('fac_cyborgs')and'cyborg'or epath:find('fac_illuminate')and'illuminate'
     or(epath:find('fac_helldivers')or epath:find('seaf'))and'seaf'or nil
    local pkgs={}
    for _,fid in ipairs({'package','dependant_package'})do
     local part=p.by_id[fid..'_lo']
     local r=part and part.row
     local lo,hi=r and c.read(r.parts[1].field),r and c.read(r.parts[2].field)
     local ph=lo and hi and string.format('%08X%08X',hi,lo)
     if ph and ph~='0000000000000000'and DATA.catalog[ph]then
      pkgs[#pkgs+1]=ph
      local pkg=DATA.catalog[ph]
      pkg.entity_kind=pkg.entity_kind or spec.KEY
      pkg.faction=pkg.faction or fac
      if not pkg.label and p.name~=p.entity_hash then pkg.label=p.name end
     end
    end
    if #pkgs>0 then M.entity_packages[p.entity_hash]=pkgs end
    local original={};for _,r in ipairs(p.rows)do original[#original+1]=r end;p.rows={}
    for _,r in ipairs(original)do p.rows[#p.rows+1]=r;if r.id=='package'or r.id=='dependant_package'then package_row(p,r)end end
    if p.name==p.entity_hash then
     local part=p.by_id.package_lo
     if part then
      local row=part.row;local lo,hi=c.read(row.parts[1].field),c.read(row.parts[2].field)
      local pkg=lo and hi and DATA.catalog[string.format('%08X%08X',hi,lo)]
      if pkg and pkg.path~=''then p.name=pkg.path:match('([^/]+)$')..' · '..p.entity_hash:sub(1,6)end
     end
    end
    p.note_of=function()return tx({'Local dependency declarations; loaded when the owning game flow requests them.',
     '本地依赖声明；随所属流程请求加载。不会立即触发热加载。','本機相依宣告；隨所屬流程請求載入。不會立即觸發熱載入。'})end
    M.pages[spec.SLOT][#M.pages[spec.SLOT]+1]=p
   end
  elseif c.log then c.log('preload: component layout mismatch '..spec.TYPE)end
 end
 for _,r in ipairs(DATA.roots)do
  if M.check_layout(r.hash,c.schemas)then
   local lists=r.hash==0x30EB6399 and c.stratagem_groups or(c.kinds[r.hash]and c.kinds[r.hash].list)or{}
   for _,kind in ipairs(lists)do
  require('startup_work').checkpoint()
    local t=c.tables[kind];local b=c.bytes(kind);local addr=t.copies[1]+24
    local idx,why=M.parse(b,r.hash,addr)
    if idx and(#idx.fields>0 or #idx.arrays>0)then
     local short=idx.identity:match('^(.-) · ')or idx.identity
     short=short:match('([^/]+)$')or short
     local p=page(r.name..' · '..short,r.slot,r.hash..'/'..kind)
     p.preload_order=r.slot=='PreloadLoadout'and 2 or r.hash==0x68E17506 and 1 or r.hash==0x08C2B982 and 2 or 3
     p.source_file=r.file;p.root_type=r.hash
     p.preload_arrays,p.preload_blob=idx.arrays,b
     local location=M.location(t.copies[1]);p.source_block=location and location:match(':(%d+)$')
     p.search=p.search..' '..idx.identity
     p.note_of=function()return r.name..' · '..tx({'Package types/offsets checked; legacy member names are inferred.',
      '包类型与偏移已核对；旧版参数名为推断。','包類型與偏移已核對；舊版參數名為推斷。'})end
     readonly(p,'source',{'Source file','来源文件','來源檔案'},r.file)
     if p.source_block then readonly(p,'block',{'Source block ordinal','来源块序号','來源區塊序號'},p.source_block)end
     readonly(p,'record',{'Record name / inheritance','记录名／继承来源','記錄名／繼承來源'},idx.identity)
     for _,a in ipairs(idx.arrays)do
      local label=a.alias or a.label
      readonly(p,'count_'..a.offset,{label..' · array count',label..' · 数组项数',label..' · 陣列項數'},tostring(a.count))
     end
     for _,entry in ipairs(idx.fields)do
      local id='package_'..entry.offset;local lo=c.field_at(kind,entry.offset,'u32',4294967295)
      local hi=c.field_at(kind,entry.offset+4,'u32',4294967295)
      local label=(entry.alias and(entry.alias..' (?) · ')or'package · ')..entry.label
      local row=c.add_row(p,'Packages',id,label,'u64',{{id=id..'_lo',field=lo,health_owner=owners[lo.key]},
       {id=id..'_hi',field=hi,health_owner=owners[hi.key]}},0,4294967295,1,1)
      row.hash64,row.lead=true,true;p.field_keys[lo.key],p.field_keys[hi.key]=true,true
      row.preload_array_item=entry.array_offset~=nil
      row.section_of=function()return tx({'Packages','资源包','資源包'})end
      row.tip_of=function()return{r.file,entry.label,tx({'Current offset and uint64 type checked against the installed type library.',
       '当前偏移及 uint64 类型已按已安装游戏类型库核对。','目前偏移及 uint64 類型已依已安裝遊戲類型庫核對。'}),
       tx({'Legacy member name is inferred; package hash matches verified local package entries.',
       '旧版成员名为推断；包哈希已与本地 package 条目匹配。','舊版成員名為推斷；包雜湊已與本機 package 項目匹配。'})}end
      package_row(p,row)
     end
    elseif not idx and c.log then c.log('preload: rejected '..r.name..': '..tostring(why))end
   end
  elseif c.log then c.log('preload: schema mismatch '..r.name)end
 end
 for h,pkg in pairs(DATA.catalog)do
  require('startup_work').checkpoint()
  local name=pkg.path~=''and pkg.path or(pkg.label and(pkg.label..' [0x'..h..']'))or'0x'..h
  local p=page(name,'PreloadCatalog',h)
  p.note_of=function()return DATA.build..' · '..tx({'Package descriptor snapshot (read-only).','资源包描述符快照（只读）。','資源包描述符快照（唯讀）。'})end
  readonly(p,'hash','package hash','0x'..h);readonly(p,'decimal','package hash (decimal)',M.hash_input('0x'..h));readonly(p,'path','package path',name)
  readonly(p,'archive','archive',table.concat(pkg.archives,', '))
  p.search=p.search..' '..h..' '..(pkg.label or'')..' '..(pkg.faction or'')
  local manifest=DATA.manifests[pkg.path]
  if manifest then
   readonly(p,'resources',{'Manifest entries','清单条目数','清單項目數'},tostring(manifest.entries))
   readonly(p,'descriptors',{'Package descriptors','包描述符数','包描述符數'},tostring(manifest.package_descriptors))
   local types={};for typ in pairs(manifest.resource_types)do types[#types+1]=typ end;table.sort(types)
   for _,typ in ipairs(types)do readonly(p,'type_'..typ,typ,tostring(manifest.resource_types[typ]))end
   if pkg.path=='packages/boot'or pkg.path=='packages/pre_boot'or pkg.path=='packages/content/global_resources'or pkg.path:find('^packages/content/mission_')then
    local q=page(name,'PreloadGlobal',h);q.rows=p.rows;q.search=p.search
    q.preload_order=pkg.path=='packages/content/global_resources'and 1 or pkg.path:find('/mission_')and 2 or 3
    q.note_of=function()return DATA.build..' · '..tx({'Resource manifest, read-only. Descriptor presence does not establish when content is loaded.',
     '资源清单（只读）；描述符存在不代表包内容已加载。','資源清單（唯讀）；描述符存在不代表包內容已載入。'})end
   end
  end
 end
 for _,rpc in ipairs(DATA.rpcs)do
  local p=page(rpc.name,'PreloadHotjoin',rpc.name)
  p.note_of=function()return tx({'Protocol metadata only; current hot-loading behavior has not been verified.',
   '仅协议元数据；当前热加载行为尚未验证。','僅通訊協定中繼資料；目前熱載入行為尚未驗證。'})end
  readonly(p,'operation','operation',rpc.name);readonly(p,'argc','argument_count',tostring(rpc.argument_count))
  readonly(p,'hash','name_hash (thin)',rpc.thin_hash)
  readonly(p,'args','argument descriptor indices',table.concat(rpc.argument_descriptor_indices,', '))
 end
 local empty=page('ResourceDependencyComponentData','PreloadHotjoin','empty-resource-dependency')
 readonly(empty,'active',{'Active entity mappings','有效实体映射数','有效實體對應數'},'0')
 empty.note_of=function()return tx({'Snapshot: unused zero record, not a preload switch.',
  '当前快照为空表；未使用的全零记录不是预载开关。','目前快照為空表；未使用的全零記錄不是預載開關。'})end
 for _,list in pairs(M.pages)do
  local counts={};for _,p in ipairs(list)do counts[p.name]=(counts[p.name]or 0)+1 end
  for _,p in ipairs(list)do if counts[p.name]>1 and p.source_block then p.name=p.name..' [#'..p.source_block..']'end end
  table.sort(list,function(a,b)
  if(a.preload_order or 1)~=(b.preload_order or 1)then return(a.preload_order or 1)<(b.preload_order or 1)end
  local aa,bb=a.name==a.entity_hash,b.name==b.entity_hash
  if aa~=bb then return not aa end
  if a.name==b.name then return a.hash<b.hash end
  return a.name:lower()<b.name:lower()
 end)end
 local model=rawget(_G,'SHODAN_PRELOAD_MODEL')
 if model then require('preload_authoring').bind(M,c,model)end
 return M.pages
end
function M.list(tab,query,tr)
 local list=M.pages[tab];if not list then return end
 if tab=='PreloadExtra'then return list end
 if not query or query==''then return list end
 local out={};for _,p in ipairs(list)do
  local s=(p.search or p.name)..' '..p.hash..' '..(tr and tr(p.name)or'');local found=true;s=s:lower()
  for word in query:lower():gmatch('%S+')do if not s:find(word,1,true)then found=false;break end end
  if found then out[#out+1]=p end
 end;return out
end
return M
