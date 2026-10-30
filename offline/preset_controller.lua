local Library=require('preset_library')
local V=require('component_view')
local Global=require('global_preset')
local I=require('install')
local M={}
function M.new(c)
 local ui=c.ui
 local P={scope='global',scopes={{id='global',label={'Global presets','全局预设','全局預設'}}}}
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function say(s)ui.message={text=tostring(s),till=c.now()+7};c.log(tostring(s));ui.version=ui.version+1 end
 local function attempt(fn)
  local ok,a,b=pcall(fn);if not ok then say(a);return nil,tostring(a)end
  if not a then say(b or'Preset operation failed');return nil,b end;return a,b
 end
 function P.load_presets()
  P.directory=c.preset_folder and c.preset_folder()or(c.folder()..'/Presets')
  I.mkdirs(P.directory)
  -- one file per preset, named after it (preset_library.lua's folder storage; preset_files.lua: Unicode names)
  P.library=Library.new({dir=P.directory,log=c.log})
  local function bring(what,fn,...)   -- an import that must not stop the editor: logged
   local done,ok,n=pcall(fn,P.library,...)
   if not(done and ok)then c.log('presets: '..what..' not imported: '..tostring(done and n or ok))
   elseif n>0 then c.log('presets: '..n..' imported from '..what)end
  end
  -- the first global-preset builds kept every preset in one preset_library.json here: split into one file each,
  -- that file kept under backup\ (so the folder lists the presets only)
  local single=P.directory..'/preset_library.json'
  if I.read(single)then
   local done,ok,n=pcall(P.library.import_library,P.library,single)
   if done and ok then
    I.mkdirs(P.directory..'/backup');I.move_file(single,P.directory..'/backup/preset_library (old format).json',9)
    c.log('presets: '..tostring(n)..' split out of preset_library.json')
   else c.log('presets: preset_library.json not split: '..tostring(done and n or ok))end
  end
  -- the folder used last time (build_release.bat makes a new build folder each time, each with its own
  -- Presets): its presets come along once. First, so its import markers keep the older sources below from
  -- adding the same presets again.
  local last_file=c.folder()..'/presets_folder.txt'
  local last=I.read(last_file);last=last and last:match('^%s*(.-)%s*$')
  if last and last~=''and last~=P.directory then
   bring(last,P.library.import_folder,last)
   bring(last..'/preset_library.json',P.library.import_library,last..'/preset_library.json')
  end
  if last~=P.directory then local f=io.open(last_file,'wb');if f then f:write(P.directory);f:close()end end
  local migrated,count=P.library:import_library(c.folder()..'/preset_library.json');assert(migrated,count)
  local ok,count=P.library:import_legacy(c.folder(),c.parse_number);assert(ok,count)
  assert(P.library:globalize())
  local path=P.directory..'/README.txt'
  if not I.read(path)then
   local f=assert(io.open(path,'wb'));assert(f:write('SHODAN Stat Editor 全局预设文件夹\r\n\r\n每个预设是这里的一个文件，以预设名命名（例如 Horde.json、精英.json）。preset_index.json 记录编号与导入标记，请勿删除。\r\n每个预设一次保存全部修改：游戏参数、敌人参数（含敌人生成与全局倍率）、拆毁修改、存档配装和预载方案。\r\n子文件夹就是分组，可在界面中新建分组、移动预设和编辑描述。\r\n分享：把预设文件复制到别人的 Presets 文件夹，重新打开编辑器即可看到。备份：复制整个 Presets 文件夹。\r\n载入只暂存修改；游戏文件与存档仍需点击对应的写入按钮。\r\n'));assert(f:close())
  end
  c.log('named presets: '..#P.library.document.items..'; imported legacy entries: '..count)
 end
 function P.open_folder()return c.open_folder and c.open_folder(P.directory)end
 function P.list()
  local out={};for _,p in ipairs(P.library and P.library:list()or{})do out[p.id]=p end;return out
 end
 function P.groups()
  local out={{id='*',label=tx('All groups','全部分组')},{id='',label=tx('Ungrouped','未分组')}}
  for _,folder in ipairs(P.library:groups())do if folder~=''then out[#out+1]={id=folder,label=folder}end end;return out
 end
 function P.select_group(id)
  local ok,why=P.finish_rename(true);if not ok then return nil,why end
  ui.preset_group=id;ui.fpage=1;ui.fslot=nil;ui.preset_menu=nil;ui.confirm=nil
  ui.preset_tree=nil;ui.preset_detail_scroll=1;ui.preset_description_scroll=1
  ui.version=ui.version+1;return true
 end
 function P.cycle_group(direction)
  local groups=P.groups();local at=1
  for i,g in ipairs(groups)do if g.id==(ui.preset_group or'*')then at=i end end
  return P.select_group(groups[(at-1+(direction=='next'and 1 or-1))%#groups+1].id)
 end
 function P.full_order()
  local out={};for _,p in ipairs(P.library and P.library:list()or{})do
   if not ui.preset_group or ui.preset_group=='*'or(p.group or'')==ui.preset_group then out[#out+1]=p.id end
  end;return out
 end
 function P.chosen()
  for _,id in ipairs(P.full_order())do if id==ui.fslot then return id end end
  ui.fslot=P.full_order()[1];return ui.fslot
 end
 function P.show(n)
  local p=P.list()[n];if p and ui.preset_group and ui.preset_group~='*'and ui.preset_group~=(p.group or'')then ui.preset_group=p.group or''end
  if ui.fslot~=n then ui.preset_tree=nil;ui.preset_detail_scroll=1;ui.preset_description_scroll=1 end
  ui.fslot=n;local rows=ui.preset_rows or 27
  for k,id in ipairs(P.full_order())do if id==n then
   if k<ui.fpage then ui.fpage=k elseif k>=ui.fpage+rows then ui.fpage=k-rows+1 end;break
  end end
  ui.version=ui.version+1
 end
 function P.finish_rename(keep)
  local edit=ui.editing;if not edit then return true end
  if keep then
   local ok,why
   if edit.kind=='group'then
    ok,why=P.library:create_group(edit.text)
    if ok then ui.preset_group=why;ui.fslot=nil;ui.fpage=1 end
   elseif edit.kind=='description'then ok,why=P.library:metadata(edit.n,'description',edit.text)
   else ok,why=P.library:rename(edit.n,edit.text)end
   if not ok then say(why);return nil,why end
  end
  ui.editing=nil;ui.version=ui.version+1;return true
 end
 function P.select_scope(scope)
  if not Library.SCOPES[scope]then return nil,'Unknown preset category'end
  local ok,why=P.finish_rename(true);if not ok then return nil,why end
  -- Old callers may still name a category. They all address the same global list.
  P.scope='global';ui.confirm=nil;ui.version=ui.version+1;return true
 end
 function P.capture()
  return Global.capture(c)
 end
 -- Stored snapshot entries include unchanged equipment and default preload settings.
 function P.saved_count(p)
  if p.scope=='global'then return Global.count(p)end
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
 function P.count(p)
  local n=0;for _,page in ipairs(P.detail_pages(p))do n=n+page.count end;return n
 end
 function P.current_count()local ok,value=pcall(P.capture);if not ok or not value then return 0 end;value.scope=P.scope;return P.count(value)end
 function P.can_capture()local ok,value=pcall(P.capture);return ok and value~=nil end
 function P.start_rename(n)
  local p=P.list()[n];if p then ui.editing={n=n,text=p.name,fresh=true};ui.version=ui.version+1 end
 end
 function P.start_description(n)
  local p=P.list()[n];if p then ui.editing={n=n,kind='description',text=p.description or'',fresh=false};ui.version=ui.version+1 end
 end
 function P.start_group()ui.preset_menu=nil;ui.editing={kind='group',text='',fresh=false};ui.version=ui.version+1 end
 function P.move_group(id)
  return attempt(function()
   local n=P.chosen();if not n then return nil,'No preset selected'end
   local ok,why=P.library:metadata(n,'group',id);if not ok then return nil,why end
   ui.preset_menu=nil;ui.preset_group=id;P.show(n);return true
  end)
 end
 function P.type_char(char)
  local edit=ui.editing;if not edit then return end
  if char==false then edit.text=edit.fresh and''or edit.text:gsub('[%z\1-\127\194-\244][\128-\191]*$','')
  else if edit.fresh then edit.text=''end;if #edit.text+#char<=(edit.kind=='description'and 4096 or edit.kind=='group'and 240 or 120)then edit.text=edit.text..char end end
  edit.fresh=false;ui.version=ui.version+1
 end
 function P.new_full_preset()
  return attempt(function()
   local payload,why=P.capture();if not payload then return nil,why end
   payload.group=ui.preset_group~='*'and ui.preset_group or''
   local id;id,why=P.library:create(P.scope,tx('Preset ','预设 ')..P.library.document.next_id,payload)
   if not id then return nil,why end;P.show(id);P.start_rename(id);return id
  end)
 end
 function P.load_full_preset(n)
  return attempt(function()
   local p=P.list()[n];if not p then return nil,'Preset no longer exists'end
   if not c.enabled()then return nil,'请先在设置中开启修改。'end
   local ok,why=Global.apply(c,p)
   if not ok then return nil,why end
   say(tx('Loaded global preset: ','已载入全局预设：')..p.name..(why and('；'..why)or'')..(p.data and p.data.loadout and'；配装已暂存，需另行写入存档。'or''))
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
     payload.kind,payload.scope='snapshot','global'
     ok,why=P.library:replace(n,payload)
    end
    if not ok then return nil,why end;say(tx(kind=='delete'and'Deleted preset: 'or'Saved preset: ',kind=='delete'and'已删除预设：'or'已保存预设：')..p.name);return true
   end)
  end
  ui.confirm={n=n,kind=kind,till=c.now()+3};ui.version=ui.version+1;return true
 end
 function P.detail_pages(p)
  local stamp=tostring(P.library.revision)..':'..c.lang()..':'..tostring(c.detail_version and c.detail_version())
  if P.detail_stamp~=stamp then P.detail_cache={};P.detail_stamp=stamp end
  -- Unsaved capture previews have no ID and must never reuse a named preset's cache.
  if not p.id then return require('preset_details').build(p,c)end
  if not P.detail_cache[p.id]then P.detail_cache[p.id]=require('preset_details').build(p,c)end
  return P.detail_cache[p.id]
 end
 -- Each preset starts with every main page collapsed. Multiple branches can stay open.
 function P.details(p)
  local tree=ui.preset_tree
  if not tree or tree.id~=p.id then tree={id=p.id,pages={},sections={}};ui.preset_tree=tree;ui.preset_detail_scroll=1 end
  local out={}
  for _,page in ipairs(P.detail_pages(p))do
   out[#out+1]={kind='page',id=page.id,label=page.label,count=page.count,expanded=tree.pages[page.id],height=32}
   if tree.pages[page.id]then for _,section in ipairs(page.sections)do if section.count>0 then
    local key=page.id..'/'..section.id
    out[#out+1]={kind='section',id=key,label=section.label,count=section.count,expanded=tree.sections[key],height=30}
    if tree.sections[key]then for _,entry in ipairs(section.rows)do if entry.changed then
     out[#out+1]={kind='parameter',entry=entry,height=50}
    end end end
   end end end
  end
  return out
 end
 function P.toggle_detail(kind,id)
  local p=P.list()[P.chosen()];if not p then return end
  local rows=P.details(p)
  for _,entry in ipairs(rows)do if entry.kind==kind and entry.id==id and entry.count>0 then
   local open=kind=='page'and ui.preset_tree.pages or ui.preset_tree.sections
   open[id]=not open[id];ui.preset_menu=nil;ui.version=ui.version+1;return true
  end end
 end
 function P.file_name()return P.directory..'/preset_library.json'end
 return P
end
return M
