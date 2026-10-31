local Library=require('preset_library')
local V=require('component_view')
local Global=require('global_preset')
local I=require('install')
local Merge=require('preset_merge')
local M={}
function M.new(c)
 local ui=c.ui
 local P={scope='global',scopes={{id='global',label={'Global presets','全局预设','全局預設'}}}}
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function say(s)ui.message={text=tostring(s),till=c.now()+7};c.log(tostring(s));ui.version=ui.version+1 end
 local function outside(why)why=tostring(why or'');return why:find('outside the editor',1,true)or why:find('another editor',1,true)end
 local function attempt(fn)
  local ok,a,b=pcall(fn)
  local why=not ok and a or not a and(b or'Preset operation failed')
  if why then
   if outside(why)and P.refresh then
    local reread=P.refresh(true)
    if reread then why=tostring(why)..tx(' · The preset folder was read again; try once more.','；已重新读取预设文件夹，请再试一次。')end
   end
   say(why);return nil,tostring(why)
  end
  return a,b
 end
 function P.load_presets()
  P.directory=c.preset_folder and c.preset_folder()or(c.folder()..'/Presets')
  I.mkdirs(P.directory)
  -- one file per preset, named after it (preset_library.lua's folder storage; preset_files.lua: Unicode names)
  P.library=Library.new({dir=P.directory,log=c.log})
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
  -- Only import legacy formats deliberately placed in this copy's Data folder.
  -- A stale presets_folder.txt must not reconnect a portable copy to another profile.
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
  local p=P.list()[n];if p then ui.editing={n=n,text=p.name,fresh=true};require('text_edit').touch(ui.editing,c.now and c.now());ui.version=ui.version+1 end
 end
 function P.start_description(n)
  local p=P.list()[n];if p then ui.editing={n=n,kind='description',text=p.description or'',fresh=false};require('text_edit').touch(ui.editing,c.now and c.now());ui.version=ui.version+1 end
 end
 function P.start_group()ui.preset_menu=nil;ui.editing={kind='group',text='',fresh=false};require('text_edit').touch(ui.editing,c.now and c.now());ui.version=ui.version+1 end
 function P.move_group(id)
  return attempt(function()
   local n=P.chosen();if not n then return nil,'No preset selected'end
   local ok,why=P.library:metadata(n,'group',id);if not ok then return nil,why end
   ui.preset_menu=nil;ui.preset_group=id;P.show(n);return true
  end)
 end
 function P.type_char(char)
  local edit=ui.editing;if not edit then return end
  local T=require('text_edit')
  if char==false then T.erase(edit,false,false)
  else T.insert(edit,char,edit.kind=='description'and 4096 or edit.kind=='group'and 240 or 120)end
  ui.version=ui.version+1
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
   local network=p.data and p.data.network
   say(tx('Loaded global preset: ','已载入全局预设：')..p.name..(why and('；'..why)or'')..(p.data and p.data.loadout and'；配装已暂存，需另行写入存档。'or'')
    ..(network and(network.assignments or network.definitions)and tx(' · Network plans staged; enable them on the planet effects pages.','；网络劫持方案已暂存，请在星球词条页面启用。')or''))
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
 -- Presets copied into (or removed from) the folder while the editor runs: read the folder again. Never while a
 -- name or description is being edited; a merge keeps its picks but must preview again. quiet: no message unless something changed.
 function P.refresh(quiet)
  if not P.library or ui.editing then return nil end
  local before={};for _,p in ipairs(P.library:list())do before[p.name..'\0'..p.id]=true end
  local ok,library=pcall(Library.new,{dir=P.directory,log=c.log})
  if not ok then c.log('presets: refresh failed: '..tostring(library));if not quiet then say(library)end;return nil,tostring(library)end
  local added,removed,now=0,0,{}
  for _,p in ipairs(library:list())do local k=p.name..'\0'..p.id;now[k]=true;if not before[k]then added=added+1 end end
  for k in pairs(before)do if not now[k]then removed=removed+1 end end
  P.library=library;P.detail_cache={};P.detail_stamp=nil
  if not P.list()[ui.fslot or-1]then ui.fslot=nil;ui.preset_tree=nil end
  local m=ui.preset_merge
  if m then   -- the preview was made from the old files: make it again
   m.plan=nil
   if not P.list()[m.source]then ui.preset_merge=nil elseif m.target and not P.list()[m.target]then m.target=nil end
  end
  local groups=false;for _,g in ipairs(P.groups())do if g.id==ui.preset_group then groups=true end end
  if not groups then ui.preset_group='*'end
  if added+removed>0 or not quiet then
   say(tx('Preset folder read again: ','已重新读取预设文件夹：')..tx(added..' new, '..removed..' gone','新增 '..added..' 个，移除 '..removed..' 个'))
  end
  ui.version=ui.version+1;return true,added,removed
 end
 -- the preview row at `index` of the current details (P.details), for double-click jumps
 function P.detail_entry(index)
  local p=P.list()[P.chosen()];if not p then return nil end
  local item=P.details(p)[index];return item and item.kind=='parameter'and item.entry or nil
 end
 -- where the editor returns after a jump out of a preset's preview
 function P.jump_state()
  return {preset=P.chosen(),tree=ui.preset_tree,scroll=ui.preset_detail_scroll,group=ui.preset_group,fpage=ui.fpage}
 end
 function P.restore(state)
  if not state or not P.list()[state.preset or-1]then return nil end
  ui.preset_group=state.group or ui.preset_group;P.show(state.preset)
  if state.tree and state.tree.id==state.preset then ui.preset_tree=state.tree end
  ui.preset_detail_scroll=state.scroll or 1;ui.fpage=state.fpage or ui.fpage;ui.version=ui.version+1;return true
 end
 -- ---------------------------------------------------------------- merge selected contents into another preset
 local function rows_of(p)
  local out={};for _,page in ipairs(P.detail_pages(p))do for _,section in ipairs(page.sections)do for _,row in ipairs(section.rows)do
   if row.changed and row.pick then out[#out+1]={page=page.id,section=page.id..'/'..section.id,row=row}end
  end end end;return out
 end
 function P.merge_start()
  local ok,why=P.finish_rename(true);if not ok then return nil,why end
  local n=P.chosen();local p=n and P.list()[n];if not p then return nil,'No preset selected'end
  if #rows_of(p)==0 then say(tx('This preset holds no changes to merge.','此预设没有可合并的改动。'));return nil end
  ui.preset_merge={source=n,picked={},keep=false};ui.preset_menu=nil;ui.confirm=nil;ui.version=ui.version+1;return true
 end
 function P.merge_cancel()ui.preset_merge=nil;ui.preset_menu=nil;ui.version=ui.version+1;return true end
 local function scope_keys(kind,id)
  local m=ui.preset_merge;local p=m and P.list()[m.source];if not p then return{}end
  local out,seen={},{}
  for _,e in ipairs(rows_of(p))do
   if(kind=='page'and e.page==id)or(kind=='section'and e.section==id)or(kind=='entry'and e.row.pick==id)then
    if not seen[e.row.pick]then seen[e.row.pick]=true;out[#out+1]=e.row.pick end
   end
  end
  return out
 end
 function P.merge_state(kind,id)
  local m=ui.preset_merge;if not m then return nil end
  local list=scope_keys(kind,id);local on=0
  for _,k in ipairs(list)do if m.picked[k]then on=on+1 end end
  return #list==0 and'none'or on==#list and'all'or on>0 and'some'or'none'
 end
 function P.merge_toggle(kind,id)
  local m=ui.preset_merge;if not m then return end
  local value=P.merge_state(kind,id)~='all'
  for _,k in ipairs(scope_keys(kind,id))do m.picked[k]=value or nil end
  m.plan=nil;ui.version=ui.version+1
 end
 function P.merge_count()local n=0;for _ in pairs(ui.preset_merge and ui.preset_merge.picked or{})do n=n+1 end;return n end
 function P.merge_targets()
  local m=ui.preset_merge;local out={}
  for _,p in ipairs(P.library:list())do if p.id~=(m and m.source)then out[#out+1]={id=tostring(p.id),label=p.name..((p.group or'')~=''and('  · '..p.group)or'')}end end
  return out
 end
 function P.merge_target(id)
  local m=ui.preset_merge;id=tonumber(id)
  if m and id and id~=m.source and P.list()[id]then m.target=id;m.plan=nil end
  ui.preset_menu=nil;ui.version=ui.version+1
 end
 function P.merge_keep()local m=ui.preset_merge;if m then m.keep=not m.keep;m.plan=nil;ui.version=ui.version+1 end end
 -- the plan, with every listed item's label and both values for the preview
 function P.merge_preview()
  local m=ui.preset_merge;if not m then return nil end
  local source,target=P.list()[m.source],P.list()[m.target or-1]
  if not source then P.merge_cancel();return nil,'Preset no longer exists'end
  if not target then say(tx('Choose the preset to merge into.','请先选择合并目标预设。'));return nil end
  local refs,labels={},{}
  for _,e in ipairs(rows_of(source))do if m.picked[e.row.pick]then
   refs[#refs+1]=e.row.ref
   local l=labels[e.row.pick]
   if not l then labels[e.row.pick]={entity=e.row.entity,label=e.row.label,value=e.row.value,rows=1}else l.rows=l.rows+1 end
  end end
  local target_rows={}
  for _,page in ipairs(P.detail_pages(target))do for _,section in ipairs(page.sections)do for _,row in ipairs(section.rows)do
   if row.pick then local t=target_rows[row.pick]or{changed=false};t.changed=t.changed or row.changed;t.value=t.value or row.value;target_rows[row.pick]=t end
  end end end
  local ok,plan=pcall(Merge.plan,source,target,refs,{keep_target=m.keep,
   target_unchanged=function(key)local t=target_rows[key];return t~=nil and not t.changed end})
  if not ok then say(plan);return nil,tostring(plan)end
  plan.labels,plan.target_rows=labels,target_rows
  m.plan=plan;ui.preset_detail_scroll=1;ui.version=ui.version+1;return plan
 end
 -- preview lines: {text, tone} tone: 'head' | 'add' | 'conflict' | 'kept' | 'blocked' | 'muted'
 function P.merge_lines()
  local m=ui.preset_merge;local plan=m and m.plan;if not plan then return{}end
  local out={}
  local function line(t,tone)out[#out+1]={text=t,tone=tone}end
  local function name(e)local l=plan.labels[e.key]or{};return(l.entity or'?')..' / '..(l.label or e.key)..((l.rows or 1)>1 and(' (+'..(l.rows-1)..')')or'')end
  local function old(e)local t=plan.target_rows[e.key];return t and t.value or'?'end
  local function new(e)local l=plan.labels[e.key];return l and l.value or'?'end
  line(tx('New in the target: ','目标中新增：')..#plan.added..tx(' · conflicts: ',' · 冲突：')..(#plan.conflicts+#plan.kept)
   ..tx(' · already equal: ',' · 已相同：')..#plan.same..tx(' · cannot merge: ',' · 无法合并：')..#plan.blocked,'head')
  if #plan.conflicts+#plan.kept>0 then
   line(m.keep and tx('Conflicts keep the target\'s value:','冲突项保留目标原值：')or tx('Conflicts take this preset\'s value (target → merged):','冲突项改用本预设的值（目标原值 → 合并后）：'),'head')
   for _,e in ipairs(plan.conflicts)do line('  '..name(e)..'   '..old(e)..' → '..new(e),'conflict')end
   for _,e in ipairs(plan.kept)do line('  '..name(e)..'   '..tx('kept ','保留 ')..old(e)..tx(' (this preset: ','（本预设：')..new(e)..tx(')','）'),'kept')end
  end
  if #plan.added>0 then
   line(tx('Added:','新增：'),'head')
   for _,e in ipairs(plan.added)do line('  '..name(e)..'   '..new(e),'add')end
  end
  if #plan.blocked>0 then
   line(tx('Cannot merge:','无法合并：'),'head')
   for _,e in ipairs(plan.blocked)do line('  '..name(e)..'   '..tostring(e.why),'blocked')end
  end
  if #plan.same>0 then
   line(tx('Already equal in the target:','目标中已相同：'),'head')
   for _,e in ipairs(plan.same)do line('  '..name(e),'muted')end
  end
  return out
 end
 function P.merge_apply()
  local m=ui.preset_merge;local plan=m and m.plan;if not plan then return nil end
  local target=P.list()[m.target or-1];if not target then return nil,'Preset no longer exists'end
  if plan.changes==0 then say(tx('Nothing to merge: the target already holds these values.','无需合并：目标预设已包含这些值。'));return nil end
  return attempt(function()
   local ok,why=P.library:replace(target.id,plan.payload);if not ok then return nil,why end
   local n,name=plan.changes,target.name
   ui.preset_merge=nil;P.show(target.id)
   say(tx('Merged '..n..' item(s) into ','已合并 '..n..' 项到预设：')..name..(#plan.blocked>0 and tx(' · '..#plan.blocked..' skipped','；跳过 '..#plan.blocked..' 项')or''))
   return true
  end)
 end
 function P.file_name()return P.directory..'/preset_library.json'end
 return P
end
return M
