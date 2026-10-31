-- Read-only preview of the saved payload, grouped by the editor's own navigation.
local V=require('component_view')
local J=require('json_data')
local U=require('stratagem_components')
local Merge=require('preset_merge')
local M={}
local function keys(t)local out={};for k in pairs(t or{})do out[#out+1]=k end;table.sort(out,function(a,b)return tostring(a)<tostring(b)end);return out end
local function value(v)
 if v==nil then return '?'end
 if type(v)=='table'then return J.encode(v)end
 if type(v)=='number'then
  if math.abs(v)==3.4028234663852886e38 then return v<0 and'-FLT_MAX'or'FLT_MAX'end
  if v%1==0 and math.abs(v)<=9007199254740992 then return string.format('%.0f',v)end
  return require('numeric_policy').display(v)
 end
 return tostring(v)
end
function M.build(p,c)
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function tr(v)return type(v)=='table'and V.pick(c.lang(),v)or c.tr(v)end
 local pages,by_tab={},{}
 for _,spec in ipairs(c.navigation or{})do
  local page={id=spec.id,label=tr(spec.name),sections={},count=0}
  for si,sub in ipairs(spec.subs)do for _,tab in ipairs(sub.tabs or{})do
   local tab_label=c.tab_label and c.tab_label(tab)or c.tr(tab)
   local section={id=tab,label=tr(sub.name)..(tab_label~=tr(sub.name)and(' / '..tab_label)or''),rows={},count=0}
   page.sections[#page.sections+1]=section;by_tab[tab]={page,section}
  end end
  pages[#pages+1]=page
 end
 local function destination(tab)
  if by_tab[tab]then return unpack(by_tab[tab])end
  local page
  for _,v in ipairs(pages)do if v.id=='other'then page=v end end
  if not page then page={id='other',label=tx('Other saved parameters','其他已保存参数'),sections={},count=0};pages[#pages+1]=page end
  local section={id=tab,label=c.tab_label and c.tab_label(tab)or c.tr(tab),rows={},count=0}
  page.sections[#page.sections+1]=section;by_tab[tab]={page,section};return page,section
 end
 -- ref: the payload item the row shows (preset_merge.lua); jump: where double-clicking it opens the editor
 local function add(tab,entity,label,id,saved,baseline,changed,ref,jump)
  local page,section=destination(tab)
  if changed==nil then changed=baseline==nil or type(saved)~='number'or type(baseline)~='number'or saved~=baseline end
  section.rows[#section.rows+1]={entity=entity,label=label,id=id,value=value(saved),baseline=baseline~=nil and value(baseline)or nil,changed=changed,
   ref=ref,pick=Merge.key(ref),jump=jump or{tab=tab}}
  if changed then page.count=page.count+1;section.count=section.count+1 end
 end
 local saved_by,seen_u64={},{}
 for _,v in ipairs(p.values or{})do
  saved_by[v.hash]=saved_by[v.hash]or{}
  saved_by[v.hash][v.id]=v.value
 end
 for _,v in ipairs(p.values or{})do
  local w=c.by_hash[v.hash]
  if w and w.ensure_rows then w.ensure_rows()end
  local part=w and w.by_id[v.id]
  if not part and w and w.component_groups then
   for _,g in ipairs(w.component_groups)do
    if g.load then g.load()end
    part=w.by_id[v.id];if part then break end
   end
  end
  local row=part and part.row
  local label=row and(row.label_of and row.label_of()or c.tr(row.label))or v.id
  local entity=w and(w.name_of and w.name_of()or c.tr(w.name))or v.hash
  local tab=w and c.tab_of and c.tab_of(w)or'Unavailable'
  local id_lo,id_hi,key_id
  if row and row.hash64 and #row.parts==2 then
   id_lo,id_hi=row.parts[1].id,row.parts[2].id
   key_id=row.id or id_lo:gsub('_lo$','')
  else
   local stem=type(v.id)=='string'and(v.id:match('^(.*)_lo$')or v.id:match('^(.*)_hi$'))
   if stem then
    local blo=c.default_value and c.default_value(v.hash,stem..'_lo')
    local bhi=c.default_value and c.default_value(v.hash,stem..'_hi')
    local map=saved_by[v.hash]or{}
    if (blo~=nil and bhi~=nil)or(map[stem..'_lo']~=nil and map[stem..'_hi']~=nil)then
     id_lo,id_hi,key_id=stem..'_lo',stem..'_hi',stem
    end
   end
  end
  if id_lo and id_hi then
   local ukey=v.hash..':'..key_id
   if not seen_u64[ukey]then
    seen_u64[ukey]=true
    local blo=c.default_value and c.default_value(v.hash,id_lo)
    local bhi=c.default_value and c.default_value(v.hash,id_hi)
    local map=saved_by[v.hash]or{}
    local clo=map[id_lo]~=nil and map[id_lo]or blo
    local chi=map[id_hi]~=nil and map[id_hi]or bhi
    local saved_str=(type(clo)=='number'and type(chi)=='number')and U.u64_text(math.floor(clo+.5),math.floor(chi+.5))or value(v.value)
    local base_str=(type(blo)=='number'and type(bhi)=='number')and U.u64_text(math.floor(blo+.5),math.floor(bhi+.5))or nil
    add(tab,entity,label,key_id,saved_str,base_str,base_str==nil or saved_str~=base_str,
     {store='values',hash=v.hash,ids={id_lo,id_hi}},{tab=tab,hash=v.hash,id=key_id,part=id_lo})
   end
  else
   local baseline=c.default_value and c.default_value(v.hash,v.id)
   add(tab,entity,label,v.id,v.value,baseline,nil,{store='values',hash=v.hash,ids={v.id}},{tab=tab,hash=v.hash,id=v.id})
  end
 end
 local d=p.data or{}
 local game=p.scope=='game'and d or d.game or{}
 for _,key in ipairs({'stacks','own_off'})do for _,id in ipairs(keys(game[key]))do
  local title=c.passive_name and c.passive_name(id)or id
  add('Armors',title,tx(key=='stacks'and'Additional passives'or'Own passive disabled',key=='stacks'and'叠加被动'or'关闭自身被动'),key..':'..id,game[key][id],nil,true,
   {store='game',key=key,id=id},{tab='Armors',hash=string.format('FFFFFFFE%08X',tonumber(id)or 0)})
 end end
 for _,armor in ipairs(keys(game.armor_passives))do
  local names={};for _,id in ipairs(game.armor_passives[armor])do names[#names+1]=c.passive_name and c.passive_name(id)or tostring(id)end
  local page=c.by_hash[string.format('FFFFFFF8%08X',tonumber(armor))]
  add('Armors',page and c.tr(page.name)or armor,tx('Armor passive combination','护甲被动组合'),'armor_passives:'..armor,names,nil,true,
   {store='game',key='armor_passives',id=armor},{tab='Armors',hash=string.format('FFFFFFF8%08X',tonumber(armor)or 0)})
 end
 local demolition=d.demolition or{}
 local bridge=rawget(_G,'SHODAN_DEMOLITION_BRIDGE');local model=bridge and bridge.panel.model
 for _,store in ipairs({'values','stale'})do for _,id in ipairs(keys(demolition[store]))do
  local target=model and model.by_id[id]
  for _,key in ipairs(keys(demolition[store][id]))do
   local baseline;for _,slot in ipairs(target and target.levels or{})do if slot.key==key then baseline=slot.value end end
   local level,kind=key:match('^(%d+):(.+)$')
   local label=tx('Destruction record ','破坏记录 ')..(level and tonumber(level)+1 or key)..' / '..tx(kind=='hit'and'Direct hit'or'Normal hit',kind=='hit'and'直击覆盖'or'普通命中')
   local owner=target and c.by_hash[target.hash]
   local entity=owner and(owner.name_of and owner.name_of()or c.tr(owner.name))or target and c.tr(target.name)or id
   add('DemolitionComponents',entity,label,key,demolition[store][id][key],baseline,nil,
    {store='demolition',bucket=store,id=id,key=key},{tab='DemolitionComponents',hash=owner and owner.hash or nil})
  end
 end end
 local loadout=p.scope=='loadout'and d or d.loadout
 if loadout then
  local Save=require('player_save');local live=rawget(_G,'SHODAN_PLAYER_SAVE_MODEL')
  for _,key in ipairs(keys(loadout.values))do
   local f=Save.BY_KEY[key];local baseline=loadout.baseline and loadout.baseline[key]
   if baseline==nil and live and live.save and live.read then baseline=live:read(key,true)end
   add('CurrentLoadout',tx('Saved equipment','存档配装'),f and tr(f.label)or key,key,loadout.values[key],baseline,nil,{store='loadout',key=key})
  end
 end
 local preload=p.scope=='preload'and d or d.preload or{}
 local live_preload=rawget(_G,'SHODAN_PRELOAD_MODEL')
 local function package_name(hash)
  local entry=live_preload and live_preload.catalog and live_preload.catalog[hash]
  if entry then
   if entry.path and entry.path~=''then return entry.path end
   if entry.label and entry.label~=''then return entry.label..' (0x'..hash..')'end
  end
  return '0x'..hash
 end
 for _,key in ipairs({'selected','targets'})do for _,hash in ipairs(keys(preload[key]))do
  local baseline=key=='targets'and hash=='18235E0C9EC0E636'
  add(key=='selected'and'PreloadExtra'or'PreloadGlobal',package_name(hash),tx(key=='selected'and'Extra package selected'or'Load target',key=='selected'and'选择额外预载包'or'加载目标'),key,preload[key][hash],baseline,preload[key][hash]~=baseline,
   {store='preload',bucket=key,hash=hash})
 end end
 for _,hash in ipairs(keys(preload.edits))do
  local baseline=preload.edits[hash].baseline
  if not baseline and live_preload and live_preload.original then
   local ok,entries=pcall(function()return require('preload_store').parse_package(live_preload:original(hash))end)
   if ok then baseline=entries end
  end
  local after=preload.edits[hash].entries or{}
  for i=1,math.max(#after,#(baseline or{}))do
   if not baseline or value(after[i])~=value(baseline[i])then
    for _,field in ipairs({'type','name'})do
     local old=baseline and baseline[i]and baseline[i][field];local saved=after[i]and after[i][field]
     if old~=saved then
      add('PreloadCatalog',package_name(hash),tx('Package entry ','包清单条目 ')..i..tx(field=='type'and' / type'or' / resource',field=='type'and' / 类型'or' / 资源'),i..':'..field,saved or tx('(removed)','（已删除）'),old,true,
       {store='preload',bucket='edits',hash=hash})
     end
    end
   end
  end
  if #after==0 and not baseline then add('PreloadCatalog',hash,tx('Package contents','包清单内容'),'entries',{},nil,true,{store='preload',bucket='edits',hash=hash})end
 end
 for _,key in ipairs(keys(preload.arrays))do
  local entry=preload.arrays[key];local before=entry.expected or{};local after=entry.values or{}
  local spec=entry.spec or{}
  local tab=spec.domain=='modifier_entity'and(spec.root==146979202 and'PlanetModifierLists'or'GalacticModifierLists')or'PreloadWorld'
  for i=1,math.max(#before,#after)do
   if value(before[i])~=value(after[i])then
    add(tab,key,tx('Array entry ','数组条目 ')..i,tostring(i),after[i]==nil and tx('(removed)','（已删除）')or after[i],before[i],true,{store='preload',bucket='arrays',key=key})
   end
  end
 end
 if preload.merge_enabled~=nil then add('PreloadGlobal',tx('Preload settings','预载设置'),tx('Merge enabled','启用合并'),'merge_enabled',preload.merge_enabled,true,preload.merge_enabled==false,{store='preload',bucket='merge_enabled'})end
 if d.legacy_preload or d.legacy_key then add('PreloadCatalog',tx('Imported preload plan','导入的预载方案'),'legacy', 'legacy',d.legacy_preload or d.legacy_key,nil,true,{store='legacy'})end
 local network=d.network or{}
 local catalogue=require('galactic_effects').index(require('galactic_effects').data)
 local function effect_name(id)
  local e=catalogue[tonumber(id)];local name=e and e[c.lang()=='en'and'name_en'or'name_zh'];return name and name~=''and(name..' ['..id..']')or tostring(id)
 end
 local assignments=network.assignments
 if assignments then
  add('PlanetEffectAssignments',tx('Network interception','网络层劫持'),tx('Assignment master switch','星球分配总开关'),'enabled',assignments.enabled,false,assignments.enabled,
   {store='network',kind='assignments',field='enabled'})
  for _,planet in ipairs(keys(assignments.targets))do
   local target=assignments.targets[planet];local title=tx('Planet #','星球 #')..planet
   for _,id in ipairs(target.effects)do
    add('PlanetEffectAssignments',title,tx('Effect assignment','指定词条'),tostring(id),effect_name(tostring(id)),nil,true,
     {store='network',kind='assignments',planet=planet},{tab='PlanetEffectAssignments',planet=tonumber(planet)})
   end
   if target.include_icons==false then add('PlanetEffectAssignments',title,tx('Include matching icon','附带匹配图标'),'include_icons',false,true,true,
    {store='network',kind='assignments',planet=planet},{tab='PlanetEffectAssignments',planet=tonumber(planet)})end
  end
 end
 local definitions=network.definitions
 if definitions then
  add('PlanetEffectIds',tx('Network interception','网络层劫持'),tx('Definition override master switch','定义覆盖总开关'),'enabled',definitions.enabled,false,definitions.enabled,
   {store='network',kind='definitions',field='enabled'})
  for _,id in ipairs(keys(definitions.effects))do local e=definitions.effects[id]
   local ref,jump={store='network',kind='definitions',effect=id},{tab='PlanetEffectIds',effect=tonumber(id)}
   if e.enabled then add('PlanetEffectIds',effect_name(id),tx('Override this effect','覆盖本词条'),'enabled',true,false,true,ref,jump)end
   for _,key in ipairs(keys(e.changes))do add('PlanetEffectIds',effect_name(id),key,key,e.changes[key],e.base[key],nil,ref,jump)end
  end
 end
 for _,page in ipairs(pages)do for _,section in ipairs(page.sections)do
  table.sort(section.rows,function(a,b)if a.entity~=b.entity then return a.entity<b.entity end;if a.label~=b.label then return a.label<b.label end;return a.id<b.id end)
 end end
 return pages
end
return M
