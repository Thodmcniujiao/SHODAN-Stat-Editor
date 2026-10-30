-- Read-only preview of the saved payload, grouped by the editor's own navigation.
local V=require('component_view')
local J=require('json_data')
local M={}
local function keys(t)local out={};for k in pairs(t or{})do out[#out+1]=k end;table.sort(out,function(a,b)return tostring(a)<tostring(b)end);return out end
local function value(v)
 if v==nil then return '?'end
 if type(v)=='table'then return J.encode(v)end
 if type(v)=='number'then return string.format('%.9g',v)end
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
 local function add(tab,entity,label,id,saved,baseline,changed)
  local page,section=destination(tab)
  if changed==nil then changed=baseline==nil or type(saved)~='number'or type(baseline)~='number'or math.abs(saved-baseline)>1e-4 end
  section.rows[#section.rows+1]={entity=entity,label=label,id=id,value=value(saved),baseline=baseline~=nil and value(baseline)or nil,changed=changed}
  if changed then page.count=page.count+1;section.count=section.count+1 end
 end
 for _,v in ipairs(p.values or{})do
  local w=c.by_hash[v.hash];local part=w and w.by_id[v.id];local row=part and part.row
  local label=row and(row.label_of and row.label_of()or c.tr(row.label))or v.id
  local entity=w and(w.name_of and w.name_of()or c.tr(w.name))or v.hash
  local tab=w and c.tab_of and c.tab_of(w)or'Unavailable'
  local baseline=c.default_value and c.default_value(v.hash,v.id)
  add(tab,entity,label,v.id,v.value,baseline)
 end
 local d=p.data or{}
 local game=p.scope=='game'and d or d.game or{}
 for _,key in ipairs({'stacks','own_off'})do for _,id in ipairs(keys(game[key]))do
  local title=c.passive_name and c.passive_name(id)or id
  add('Armors',title,tx(key=='stacks'and'Additional passives'or'Own passive disabled',key=='stacks'and'叠加被动'or'关闭自身被动'),key..':'..id,game[key][id],nil,true)
 end end
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
   add('DemolitionComponents',entity,label,key,demolition[store][id][key],baseline)
  end
 end end
 local loadout=p.scope=='loadout'and d or d.loadout
 if loadout then
  local Save=require('player_save');local live=rawget(_G,'SHODAN_PLAYER_SAVE_MODEL')
  for _,key in ipairs(keys(loadout.values))do
   local f=Save.BY_KEY[key];local baseline=loadout.baseline and loadout.baseline[key]
   if baseline==nil and live and live.save and live.read then baseline=live:read(key,true)end
   add('CurrentLoadout',tx('Saved equipment','存档配装'),f and tr(f.label)or key,key,loadout.values[key],baseline)
  end
 end
 local preload=p.scope=='preload'and d or d.preload or{}
 local live_preload=rawget(_G,'SHODAN_PRELOAD_MODEL')
 local function package_name(hash)
  local entry=live_preload and live_preload.catalog and live_preload.catalog[hash]
  return entry and entry.path or hash
 end
 for _,key in ipairs({'selected','targets'})do for _,hash in ipairs(keys(preload[key]))do
  local baseline=key=='targets'and hash=='18235E0C9EC0E636'
  add(key=='selected'and'PreloadExtra'or'PreloadGlobal',package_name(hash),tx(key=='selected'and'Extra package selected'or'Load target',key=='selected'and'选择额外预载包'or'加载目标'),key,preload[key][hash],baseline,preload[key][hash]~=baseline)
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
      add('PreloadCatalog',package_name(hash),tx('Package entry ','包清单条目 ')..i..tx(field=='type'and' / type'or' / resource',field=='type'and' / 类型'or' / 资源'),i..':'..field,saved or tx('(removed)','（已删除）'),old,true)
     end
    end
   end
  end
  if #after==0 and not baseline then add('PreloadCatalog',hash,tx('Package contents','包清单内容'),'entries',{},nil,true)end
 end
 for _,key in ipairs(keys(preload.arrays))do
  local entry=preload.arrays[key];local before=entry.expected or{};local after=entry.values or{}
  local spec=entry.spec or{}
  local tab=spec.domain=='modifier_entity'and(spec.root==146979202 and'PlanetModifierLists'or'GalacticModifierLists')or'PreloadWorld'
  for i=1,math.max(#before,#after)do
   if value(before[i])~=value(after[i])then
    add(tab,key,tx('Array entry ','数组条目 ')..i,tostring(i),after[i]==nil and tx('(removed)','（已删除）')or after[i],before[i],true)
   end
  end
 end
 if preload.merge_enabled~=nil then add('PreloadGlobal',tx('Preload settings','预载设置'),tx('Merge enabled','启用合并'),'merge_enabled',preload.merge_enabled,true,preload.merge_enabled==false)end
 if d.legacy_preload or d.legacy_key then add('PreloadCatalog',tx('Imported preload plan','导入的预载方案'),'legacy', 'legacy',d.legacy_preload or d.legacy_key,nil,true)end
 for _,page in ipairs(pages)do for _,section in ipairs(page.sections)do
  table.sort(section.rows,function(a,b)if a.entity~=b.entity then return a.entity<b.entity end;if a.label~=b.label then return a.label<b.label end;return a.id<b.id end)
 end end
 return pages
end
return M
