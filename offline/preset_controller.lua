local Library=require('preset_library')
local V=require('component_view')
local M={}
function M.new(c)
 local ui=c.ui
 local P={scope='game',scopes={{id='game',label={'Game parameters','游戏参数','遊戲參數'}},
  {id='enemy',label={'Enemy parameters','敌人参数','敵人參數'}},
  {id='loadout',label={'Saved equipment','存档配装','存檔配裝'}},
  {id='preload',label={'Preload plans','预载方案','預載方案'}}}}
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function say(s)ui.message={text=tostring(s),till=c.now()+7};c.log(tostring(s));ui.version=ui.version+1 end
 local function attempt(fn)
  local ok,a,b=pcall(fn);if not ok then say(a);return nil,tostring(a)end
  if not a then say(b or'Preset operation failed');return nil,b end;return a,b
 end
 function P.load_presets()
  P.library=Library.new({path=c.folder()..'/preset_library.json'})
  local ok,count=P.library:import_legacy(c.folder(),c.parse_number);assert(ok,count)
  c.log('named presets: '..#P.library.document.items..'; imported legacy entries: '..count)
 end
 function P.list()
  local out={};for _,p in ipairs(P.library and P.library:list(P.scope)or{})do out[p.id]=p end;return out
 end
 function P.full_order()local out={};for _,p in ipairs(P.library and P.library:list(P.scope)or{})do out[#out+1]=p.id end;return out end
 function P.chosen()
  if not P.list()[ui.fslot or 0]then ui.fslot=P.full_order()[1]end;return ui.fslot
 end
 function P.show(n)
  ui.fslot=n;local rows=ui.preset_rows or 27
  for k,id in ipairs(P.full_order())do if id==n then
   if k<ui.fpage then ui.fpage=k elseif k>=ui.fpage+rows then ui.fpage=k-rows+1 end;break
  end end
  ui.version=ui.version+1
 end
 function P.finish_rename(keep)
  local edit=ui.editing;if not edit then return true end
  if keep then local ok,why=P.library:rename(edit.n,edit.text);if not ok then say(why);return nil,why end end
  ui.editing=nil;ui.version=ui.version+1;return true
 end
 function P.select_scope(scope)
  if not Library.SCOPES[scope]then return nil,'Unknown preset category'end
  local ok,why=P.finish_rename(true);if not ok then return nil,why end
  ui.preset_selected=ui.preset_selected or{};ui.preset_selected[P.scope]=ui.fslot
  P.scope=scope;ui.fslot=ui.preset_selected[scope];ui.fpage=1;ui.confirm=nil;ui.version=ui.version+1;return true
 end
 function P.capture()
  if P.scope=='game'or P.scope=='enemy'then return {values=c.values(P.scope=='enemy'),data=P.scope=='game'and c.game_settings()or nil}end
  if P.scope=='loadout'then
   local model=rawget(_G,'SHODAN_PLAYER_SAVE_MODEL');if not model then return nil,'存档编辑器不可用。'end
   local data,why=model:snapshot();if not data then return nil,why end;return {values={},data=data}
  end
  local model=rawget(_G,'SHODAN_PRELOAD_MODEL');if not model then return nil,'预载编辑器不可用。'end
  return {values=c.preload_values and c.preload_values()or{},data=model:snapshot()}
 end
 function P.count(p)
  if p.scope=='game'or p.scope=='enemy'then
   local count=#p.values
   if p.scope=='game'and p.data then for _,key in ipairs({'stacks','own_off'})do for _ in pairs(p.data[key]or{})do count=count+1 end end end
   return count
  end
  local n=#(p.values or{});local data=p.data or{}
  if p.scope=='loadout'then for _ in pairs(data.values or{})do n=n+1 end
  elseif data.legacy_key then n=1
  else for _,key in ipairs({'edits','arrays','selected','targets'})do for _ in pairs(data[key]or{})do n=n+1 end end end
  return n
 end
 function P.current_count()local ok,value=pcall(P.capture);if not ok or not value then return 0 end;value.scope=P.scope;return P.count(value)end
 function P.can_capture()local ok,value=pcall(P.capture);return ok and value~=nil end
 function P.start_rename(n)
  local p=P.list()[n];if p then ui.editing={n=n,text=p.name,fresh=true};ui.version=ui.version+1 end
 end
 function P.type_char(char)
  local edit=ui.editing;if not edit then return end
  if char==false then edit.text=edit.fresh and''or edit.text:gsub('[%z\1-\127\194-\244][\128-\191]*$','')
  else if edit.fresh then edit.text=''end;if #edit.text+#char<=120 then edit.text=edit.text..char end end
  edit.fresh=false;ui.version=ui.version+1
 end
 function P.new_full_preset()
  return attempt(function()
   local payload,why=P.capture();if not payload then return nil,why end
   local id;id,why=P.library:create(P.scope,tx('Preset ','预设 ')..P.library.document.next_id,payload)
   if not id then return nil,why end;P.show(id);P.start_rename(id);return id
  end)
 end
 function P.load_full_preset(n)
  return attempt(function()
   local p=P.list()[n];if not p then return nil,'Preset no longer exists'end
   if not c.enabled()then return nil,'请先在设置中开启修改。'end
   local ok,why
   if p.scope=='game'or p.scope=='enemy'then
    ok,why=c.apply(p)
   elseif p.scope=='loadout'then
    local model=rawget(_G,'SHODAN_PLAYER_SAVE_MODEL');if not model then return nil,'存档编辑器不可用。'end
    ok,why=model:apply_snapshot(p.data)
   else
    local model=rawget(_G,'SHODAN_PRELOAD_MODEL');if not model then return nil,'预载编辑器不可用。'end
    if p.data and p.data.legacy_key then ok,why=model:apply_legacy_preset(p.data.legacy_key,p.data.value)
    else ok,why=model:apply_snapshot(p.data)end
    if ok and not(p.data and p.data.legacy_key)then ok,why=c.apply(p)end
   end
   if not ok then return nil,why end
   say(tx('Loaded preset: ','已载入预设：')..p.name..(why and('；'..why)or'')..(p.scope=='loadout'and'；配装暂存，返回配装页点击“写入存档”。'or''))
   return true
  end)
 end
 function P.confirm(kind,n)
  local p=P.list()[n];if not p then return end
  local confirm=ui.confirm
  if confirm and confirm.n==n and confirm.kind==kind and c.now()<confirm.till then
   ui.confirm=nil
   return attempt(function()
    local ok,why
    if kind=='delete'then ok,why=P.library:delete(n)
    else
     local payload;payload,why=P.capture();if not payload then return nil,why end
     if p.kind=='patch'and(p.scope=='game'or p.scope=='enemy')then
      local owners={};for _,v in ipairs(p.values)do owners[v.hash]=true end
      if p.data and p.data.owner_hash then owners[p.data.owner_hash]=true end
      local values={};for _,v in ipairs(payload.values)do if owners[v.hash]then values[#values+1]=v end end;payload={values=values,data=p.data}
     end
     ok,why=P.library:replace(n,payload)
    end
    if not ok then return nil,why end;say(tx(kind=='delete'and'Deleted preset: 'or'Saved preset: ',kind=='delete'and'已删除预设：'or'已保存预设：')..p.name);return true
   end)
  end
  ui.confirm={n=n,kind=kind,till=c.now()+3};ui.version=ui.version+1;return true
 end
 function P.details(p)
  local out={}
  if p.scope=='game'or p.scope=='enemy'then
   local counts={};for _,v in ipairs(p.values)do counts[v.hash]=(counts[v.hash]or 0)+1 end
   local keys={};for key in pairs(counts)do keys[#keys+1]=key end;table.sort(keys)
   for _,hash in ipairs(keys)do local w=c.by_hash[hash];out[#out+1]={label=w and c.tr(w.name)or hash,value=tostring(counts[hash])}end
   if p.scope=='game'and p.data then
    for _,entry in ipairs({{'stacks','Passive stacks','护甲被动叠加'},{'own_off','Passive switches','护甲被动开关'}})do
     local n=0;for _ in pairs(p.data[entry[1]]or{})do n=n+1 end
     if n>0 then out[#out+1]={label=tx(entry[2],entry[3]),value=tostring(n)}end
    end
   end
  elseif p.scope=='loadout'then
   local Save=require('player_save');for _,f in ipairs(Save.FIELDS)do local value=(p.data.values or{})[f.key]
    if value~=nil then out[#out+1]={label=V.pick(c.lang(),f.label),value=tostring(value)}end
   end
  elseif p.data and p.data.legacy_key then out[1]={label=tx('Imported preload plan','导入的预载方案'),value=p.data.legacy_key}
  else
   for _,entry in ipairs({{'selected','Selected packages','选中的资源包'},{'targets','Load targets','加载目标'},{'edits','Manifest changes','包清单修改'},{'arrays','Package arrays','包数组修改'}})do
    local n=0;for _ in pairs((p.data or{})[entry[1]]or{})do n=n+1 end
    out[#out+1]={label=tx(entry[2],entry[3]),value=tostring(n)}
   end
   if #(p.values or{})>0 then out[#out+1]={label=tx('Package parameter changes','包参数修改'),value=tostring(#p.values)}end
  end
  return out
 end
 function P.file_name()return'preset_library.json'end
 return P
end
return M
