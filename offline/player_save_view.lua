-- Native editor rows. Only this page's explicit save action / host save button writes the save.
local S=require('player_save')
local V=require('component_view')
local D=require('demolition')
local M={pages={}}
function M.build(c)
 for i=#c.weapons,1,-1 do local old=c.weapons[i];if old.save_loadout then
  if c.by_hash[old.hash]==old then c.by_hash[old.hash]=nil end;table.remove(c.weapons,i)
 end end
 M.pages={};local model=rawget(_G,'SHODAN_PLAYER_SAVE_MODEL')
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function page(id,en,cn)
  local p={name=tx(en,cn),hash=D.hex(D.hash_resource('shodan/player_save/'..id)),slot='CurrentLoadout',
   rows={},by_id={},field_keys={},note='',save_loadout=true}
  p.name_of=function()return tx(en,cn)end
  p.note_of=function()return tx('Local save; stage changes, then Write save. Restart the game to verify.',
   '编辑本地存档；修改后点击“写入存档”，重启游戏检查。')end
  p.note=p.note_of();p.custom_modified=function()return model and model:count()>0 end
  p.custom_reset=function()return model and model:reset()or true end
  p.custom_preset=function(what,n)return model and model:preset(what,n)end
  p.custom_preset_values=function(n)return model and model.presets[tostring(n)]end
  c.weapons[#c.weapons+1]=p;c.by_hash[p.hash]=p;M.pages[#M.pages+1]=p;return p
 end
 local function row(p,id,en,cn,section)
  local r={id=id,label=en,label_of=function()return tx(en,cn)end,parts={},storage='u32',min=0,max=4294967295,
   section=section or'Save management',custom_value=function()return 0 end}
  r.section_of=function()return tx(section or'Save management',section=='Equipment'and'装备选择'or section=='Unknown fields'and'未命名字段（用途待验证）'or'存档管理')end
  p.rows[#p.rows+1]=r;return r
 end
 local function action(p,id,en,cn,fn)
  local r=row(p,id,en,cn);r.custom_action=function()local ok,a,b=pcall(fn);if not ok then return nil,tostring(a)end;return a,b end
  r.custom_text=function()return tx('Run','执行')end;return r
 end
 local function text(p,id,en,cn,get,set,section)
  local r=row(p,id,en,cn,section);r.input_text=get;r.custom_text=get
  r.custom_edit=function(s)local ok,a,b=pcall(set,s);if not ok then return nil,tostring(a)end;return a,b end;return r
 end
 local p=page('loadout','Saved equipment','存档配装')
 if not model then
  local r=row(p,'missing','Save editor unavailable','存档编辑器不可用');r.empty=true
  r.readonly_text=tostring(rawget(_G,'SHODAN_PLAYER_SAVE_ERROR')or'No save model');return M.pages
 end
 -- Use the editor's own localized weapon and armor names, indexed by current definitions.
 for _,item in pairs(model.catalog.by_id)do
  if item.entity then local w=c.by_hash[item.entity];if w then item.name=function()return c.tr(w.name)end end
  elseif item.loc and c.kit_names[item.loc]then local name=c.kit_names[item.loc];item.name=function()return c.tr(name)end end
 end
 local function display(key)
  local v=model:read(key);if v==nil then return tx('Choose a save first','请先读取存档')end
  local f=S.BY_KEY[key];local item=f.category and model.catalog.categories[f.category][v]
  local name=item and(type(item.name)=='function'and item.name()or item.name)
  if name and name~='ID '..v then return name end
  return tostring(v)
 end
 local status=row(p,'status','Status','状态');status.empty=true;status.readonly_text=function()return model.error or model.status end
 for _,f in ipairs(S.FIELDS)do if not f.unknown then
  local r=text(p,f.key,f.label[1],f.label[2],function()return tostring(model:read(f.key)or'')end,function(input)
   local v,why=S.integer(input)
   if not v and f.category then
    local q=input:lower();local matches={};for _,item in pairs(model.catalog.categories[f.category])do
     local name=type(item.name)=='function'and item.name()or item.name
     if name:lower():find(q,1,true)then matches[#matches+1]=item.id end
    end
    if #matches==1 then v=matches[1]else return nil,'名称匹配 '..#matches..' 项；请输入物品 ID 或更完整的名称。'end
   end
   if not v then return nil,why end;return model:set(f.key,v)
  end,'Equipment')
  r.custom_text=function()return display(f.key)end;r.custom_value=function(default)return model:read(f.key,default)or 0 end
  r.custom_reset=function()return model:reset(f.key)end
  r.tip_of=function()return{display(f.key),'ID '..tostring(model:read(f.key)or''),string.format('testament_new.sav 解压数据 +0x%X · u32',f.offset),
   f.category and'可输入十进制 ID、0x 十六进制 ID，或唯一匹配的物品名称。'or'旧 CT 军械库相对偏移对应；支持原始 u32 ID 编辑。'}end
 end end
 action(p,'write','Write save','写入存档（自动备份）',function()return model:commit()end)
 action(p,'reload','Reload from disk','重新读取磁盘存档',function()if not model.selected then return nil,'请先选择存档。'end;return model:load(model.selected)end)
 local selected='primary';local query='';local offset=0;local browser=page('catalog','Equipment catalog','装备 ID 目录')
 local refresh
 refresh=function()
  browser.rows={}
  local category_row=text(browser,'category','Slot (enter category name)','装备槽（输入类别名称）',function()return selected end,function(input)
   local aliases={['头盔']='helmet',['护甲']='armor',['披风']='cape',['主武器']='primary',['副武器']='secondary',['手雷']='grenade'}
   local key=aliases[input]or input:lower();if not model.catalog.categories[key]then return nil,'不支持的装备槽。'end;selected=key;offset=0;refresh();return true
  end)
  category_row.tip_of=function()return{'头盔 helmet / 护甲 armor / 披风 cape','主武器 primary / 副武器 secondary / 手雷 grenade'}end
  text(browser,'filter','Filter names or IDs','搜索物品名称或 ID',function()return query end,function(input)query=input;offset=0;refresh();return true end)
  local entries={};for _,item in pairs(model.catalog.categories[selected])do
   local name=type(item.name)=='function'and item.name()or item.name
   local hay=(name..' '..item.id..' '..(item.entity or'')):lower();local found=true
   for word in query:lower():gmatch('%S+')do if not hay:find(word,1,true)then found=false;break end end
   if found then entries[#entries+1]={item=item,name=name}end
  end
  table.sort(entries,function(a,b)return a.name==b.name and a.item.id<b.item.id or a.name<b.name end)
  offset=math.min(offset,math.floor(math.max(0,#entries-1)/16)*16)
  local count=row(browser,'count','Matching definitions','匹配到的物品定义');count.empty=true;count.readonly_text=tostring(#entries)
  action(browser,'prev','Previous 16','上一组 16 项',function()offset=math.max(0,offset-16);refresh();return true end)
  action(browser,'next','Next 16','下一组 16 项',function()offset=math.min(math.floor(math.max(0,#entries-1)/16)*16,offset+16);refresh();return true end)
  for i=offset+1,math.min(#entries,offset+16)do
   local entry=entries[i];local r=action(browser,'choose_'..entry.item.id,entry.name,entry.name,function()return model:set(selected,entry.item.id)end)
   r.custom_text=function()return tx('Equip','选用')..' '..entry.item.id end
   r.tip_of=function()return{entry.name,'ID '..entry.item.id,entry.item.entity or'HelldiverCustomizationKit','此目录是物品定义，不代表账号已解锁。'}end
  end
 end;refresh()
 local manage=page('manage','Save files and backups','存档与备份')
 text(manage,'path','Save path (testament_new.sav)','存档路径（testament_new.sav）',function()return model.selected or''end,function(input)
  input=input:match('^%s*"?(.-)"?%s*$');if input==''then return nil,'请输入存档完整路径。'end;return model:load(input)
 end)
 for i,path in ipairs(model.paths)do action(manage,'account_'..i,'Load detected save '..i,'读取检测到的存档 '..i,function()return model:load(path)end).tip_of=function()return{path}end end
 text(manage,'backup','Backup path to restore','要恢复的备份路径',function()return model.backup or''end,function(input)
  local raw=model.io.read(input);if not raw then return nil,'备份不存在。'end;S.decode(raw);model.backup=input;model:touch();return true
 end)
 action(manage,'restore','Restore selected backup','恢复所选存档备份',function()return model:restore()end)
 local info=row(manage,'note','Source','说明');info.empty=true
 info.readonly_text='Steam Cloud 可能同步或覆盖此本地文件。'
 local unknown=page('unknown','Unidentified save fields','未命名存档字段')
 unknown.note='字段用途尚未确认；不会把它们标成称号、体型或语音。';unknown.note_of=function()return unknown.note end
 for _,f in ipairs(S.FIELDS)do if f.unknown then
  local r=text(unknown,f.key,f.label[1],f.label[2],function()return tostring(model:read(f.key)or'')end,function(input)
   local v,why=S.integer(input);if not v then return nil,why end;return model:set(f.key,v)
  end,'Unknown fields')
  r.custom_reset=function()return model:reset(f.key)end
  r.custom_value=function(default)return model:read(f.key,default)or 0 end
  r.tip_of=function()return{string.format('解压存档 +0x%X · u32；用途未确认。',f.offset)}end
 end end
 return M.pages
end
function M.list(tab,query)
 if tab~='CurrentLoadout'then return end
 for _,p in ipairs(M.pages)do if p.name_of then p.name=p.name_of()end end
 if not query or query==''then return M.pages end
 local out={};for _,p in ipairs(M.pages)do if p.name:lower():find(query:lower(),1,true)then out[#out+1]=p end end;return out
end
return M
