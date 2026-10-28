local V=require('component_view')
local S=require('preload_store')
local D=require('demolition')
local J=require('json_data')
local I=require('install')
local M={}
function M.bind(P,c,model)
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function run(fn)
  local ok,a,b=pcall(fn);if not ok then return nil,tostring(a)end;return a,b
 end
 local function row(p,id,en,cn)
  local r={id=id,label=en,label_of=function()return tx(en,cn)end,storage='u32',parts={},min=0,max=1,small=1,big=1,section='Package authoring'}
  r.section_of=function()return tx('Package authoring','包内容与预载')end
  r.custom_value=function()return 0 end;p.rows[#p.rows+1]=r;return r
 end
 local function action(p,id,en,cn,fn,refresh)
  local r=row(p,id,en,cn);r.custom_action=function()
   local ok,why=run(fn);if ok and refresh then refresh()end;return ok,why
  end;r.custom_text=function()return tx('Run','执行')end;return r
 end
 local function text(p,id,en,cn,value,set,refresh)
  local r=row(p,id,en,cn);r.custom_text=function()local s=value();return s~=''and s or tx('Click to enter...','点击输入…')end;r.custom_edit=function(input)
   local ok,why=run(function()return set(input)end);if ok and refresh then refresh()end;return ok,why
  end;r.input_text=value;return r
 end
 local function flag(p,id,en,cn,kind,h)
  local r=row(p,id,en,cn);r.storage='flag';r.custom_value=function(default)
   if default then return kind=='targets'and h=='18235E0C9EC0E636'and 1 or 0 end
   return model.cfg[kind][h]and 1 or 0
  end
  r.custom_change=function(v)return model:toggle(kind,h,v>=.5)end
  r.custom_reset=function()return model:toggle(kind,h,false)end
  return r
 end
 local function package_page(p,h)
  local base=p.rows;local offset=0;local refresh
  refresh=function()
   local entries=model:entries(h);p.rows={};offset=math.min(offset,math.floor(math.max(0,#entries-1)/50)*50)
   local types={};for _,manifest in pairs(P.data.manifests)do for name in pairs(manifest.resource_types)do types[S.hash(name)]=name end end
   flag(p,'donor','Select for extra preload','选为额外预载包','selected',h)
   flag(p,'target','Merge destination','选为合并加载目标','targets',h)
   action(p,'reset_manifest','Reset package contents','恢复此包内容',function()return model:mutate(function()model.cfg.edits[h]=nil end)end,refresh)
   action(p,'previous_entries','Previous 50 resources','上一组 50 个资源',function()offset=math.max(0,offset-50);return true end,refresh)
   action(p,'next_entries','Next 50 resources','下一组 50 个资源',function()offset=math.min(math.floor(math.max(0,#entries-1)/50)*50,offset+50);return true end,refresh)
   local add=text(p,'add_resource','Append resource (type name)','追加资源（类型 名称）',function()return''end,
    function(input)return model:edit_entry(h,#entries+1,input)end,refresh)
   add.tip_of=function()return{tx('Example: texture 0x0123456789ABCDEF; enter - on an existing entry to delete it.',
    '例如 texture 0x0123456789ABCDEF；修改已有项时输入 - 可删除。')}end
   for i=offset+1,math.min(offset+50,#entries)do
    local item=entries[i]
    local r=text(p,'resource_'..i,'Resource '..i,'资源 '..i,
     function()return(types[item.type]or'0x'..item.type)..' 0x'..item.name end,function(input)return model:edit_entry(h,i,input)end,refresh)
    r.tip_of=add.tip_of
   end
   local info=row(p,'count_current','Current resource count','当前资源条目数');info.empty=true;info.readonly_text=tostring(#entries)
   local counts={};for _,e in ipairs(entries)do counts[e.type]=(counts[e.type]or 0)+1 end
   for _,r in ipairs(base)do
    if r.id=='resources'then r.readonly_text=tostring(#entries)
    elseif r.id=='descriptors'then r.readonly_text=tostring(counts[S.PTYPE]or 0)
    elseif r.id:match('^type_')then r.readonly_text=tostring(counts[S.hash(r.id:sub(6))]or 0)end
    p.rows[#p.rows+1]=r
   end
   p.custom_modified=function()return model.cfg.edits[h]or model.cfg.selected[h]or next(model.cfg.selected)and model.cfg.targets[h]end
   p.custom_reset=function()local ok,why=model:reset('package',h);if ok then refresh()end;return ok,why end
   p.custom_preset=function(what,n)local ok,why=model:preset(what,h,n,'package');if ok then refresh()end;return ok,why end
   p.model_version=model.version
  end
  p.ensure_rows=function()
   if p.authoring_ready and p.model_version==model.version then return end
   local ok,why=run(function()refresh();return true end)
   if ok then p.authoring_ready=true else
    p.rows={};local r=row(p,'load_error','Package read failed; retry below','包读取失败，可在下方重试');r.empty=true;r.readonly_text=tostring(why)
    action(p,'retry','Retry reading package','重试读取此包',function()refresh();p.authoring_ready=true;return true end)
   end
  end
  p.note_of=function()return tx('Editable manifest; additions replace the saved manifest after Install. - removes an entry.',
   '可编辑包清单；点击写入游戏后生效。已有项输入 - 删除，类型与名称之间用空格分隔。')end
 end
 for _,slot in ipairs({'PreloadGlobal','PreloadCatalog'})do for _,p in ipairs(P.pages[slot])do
  -- Both views share the same package backing store, but each gets its own lazy row list.
  local h=p.search:match('(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)$')
  if not h then for key,pkg in pairs(model.catalog)do if pkg.path==p.name or p.name=='0x'..key then h=key;break end end end
  if h then package_page(p,h)end
 end end
 -- Semantic array editing replaces only u64-array rows; scalar fields retain their existing editor storage.
 for _,p in ipairs(P.pages.PreloadWorld)do
  if p.preload_arrays and #p.preload_arrays>0 then
   local keys={};local original=p.rows;local refresh
   for _,a in ipairs(p.preload_arrays)do
    local key=p.source_file..'/'..p.root_type..'/'..p.source_block..'/'..a.offset
    local values={};for i=0,a.count-1 do values[#values+1]=D.hex(p.preload_blob:sub(a.target+i*8+1,a.target+i*8+8))end
    model:register_array(key,{file=p.source_file,root=p.root_type,ordinal=tonumber(p.source_block),offset=a.offset},values)
    for _,r in ipairs(original)do if r.id=='count_'..a.offset then r.readonly_text=function()return tostring(#model:array_values(key))end end end
    keys[#keys+1]=key
   end
   refresh=function()
    p.rows={};for _,r in ipairs(original)do if not r.preload_array_item then p.rows[#p.rows+1]=r end end
    for ai,key in ipairs(keys)do
     local values=model:array_values(key)
     action(p,'append_selected_'..ai,'Append selected packages to array '..ai,'向包数组 '..ai..' 追加选中包',function()return model:append_selected(key)end,refresh)
     text(p,'append_one_'..ai,'Append package to array '..ai,'向包数组 '..ai..' 追加一个包',function()return''end,function(input)return model:edit_array(key,#values+1,input)end,refresh)
     action(p,'reset_array_'..ai,'Reset array '..ai,'恢复包数组 '..ai,function()return model:reset('array',key)end,refresh)
     for i,h in ipairs(values)do
      local r=text(p,'array_'..ai..'_'..i,'Array '..ai..' package '..i,'数组 '..ai..' 包 '..i,function()return'0x'..h end,
       function(input)return model:edit_array(key,i,input)end,refresh)
      r.tip_of=function()return{tx('Package path, hex or decimal ID; - deletes this item.','可输入包路径、十六进制或十进制哈希；输入 - 删除此项。')}end
     end
    end
   end
   p.custom_modified=function()for _,key in ipairs(keys)do if model.cfg.arrays[key]then return true end end;return false end
   p.custom_reset=function()for _,key in ipairs(keys)do local ok,why=model:reset('array',key);if not ok then return nil,why end end;refresh();return true end
   p.custom_preset=function(what,n)for _,key in ipairs(keys)do local ok,why=model:preset(what,key,n,'array');if not ok then return nil,why end end;refresh();return true end
   refresh()
  end
 end
 local p={name='Additional package preload',hash=D.hex(D.hash_resource('shodan/preload/extra-plan')),slot='PreloadExtra',rows={},by_id={},field_keys={},preload_parameters=true}
 c.by_hash[p.hash]=p;P.pages.PreloadExtra={p}
 p.note_of=function()return tx('Select donors, choose destinations, preview, then Install. Generated plans still need an in-game loading test.',
  '选择额外包和加载目标，预览后点击写入游戏。文件生成成功与游戏实际加载分别验证。')end
 local function filtered(pattern)
  local out={};local query=pattern or(c.query and c.query()or''):lower()
  for h,pkg in pairs(model.catalog)do
   local hay=(h..' '..pkg.path):lower();local found=true
   for word in query:gmatch('%S+')do if not hay:find(word,1,true)then found=false;break end end
   if found then out[#out+1]=h end
  end
  return out
 end
 local refresh
 refresh=function()
  p.rows={}
  local mode=row(p,'merge_mode','Apply manifest merge (off = array edits only)','应用包清单合并（关闭则仅写数组修改）');mode.storage='flag'
  mode.custom_value=function(default)return(default or model.cfg.merge_enabled~=false)and 1 or 0 end
  mode.custom_change=function(v)return model:mutate(function()model.cfg.merge_enabled=v>=.5 end)end
  mode.custom_reset=function()return model:mutate(function()model.cfg.merge_enabled=true end)end
  action(p,'all','Select every package','选中所有包',function()return model:select_many(S.keys(model.catalog),true)end,refresh)
  action(p,'filter','Select packages matching search','选中搜索框匹配的包',function()return model:select_many(filtered(),true)end,refresh)
  for _,g in ipairs({{'bug','Terminid packages (named)','虫族包（已知名称）'},{'cyborg','Automaton packages (named)','机器人包（已知名称）'},{'illuminate','Illuminate packages (named)','光能者包（已知名称）'}})do
   action(p,'group_'..g[1],g[2],g[3],function()return model:select_many(filtered(g[1]),true)end,refresh)
  end
  action(p,'clear','Clear selection','清空选包',function()return model:select_many(S.keys(model.cfg.selected),false)end,refresh)
  text(p,'add_donor','Select a package by path / ID','按路径／哈希选一个包',function()return''end,function(input)return model:toggle('selected',S.input_hash(input),true)end,refresh)
  text(p,'add_target','Add merge target by path / ID','按路径／哈希添加合并目标',function()return''end,function(input)return model:toggle('targets',S.input_hash(input),true)end,refresh)
  text(p,'remove_target','Remove merge target by path / ID','按路径／哈希移除合并目标',function()return''end,function(input)return model:toggle('targets',S.input_hash(input),false)end,refresh)
  action(p,'preview','Build and preview dependency closure','生成并预览依赖展开',function()model:package_outputs();return true end,refresh)
  action(p,'export','Export configuration','导出预载配置',function()
   local path=I.home..'/preload-export.json';local f=assert(io.open(path,'wb'));assert(f:write(J.encode(model.cfg)));f:close();return true
  end)
  action(p,'import','Import preload-export.json','导入 preload-export.json',function()
   local cfg=J.decode(assert(I.read(I.home..'/preload-export.json'),'preload-export.json not found'),128*1024*1024)
   assert(cfg.version==1 and cfg.edits and cfg.selected and cfg.targets and cfg.arrays,'invalid preload configuration')
   for _,kind in ipairs({'edits','selected','targets'})do for h in pairs(cfg[kind])do assert(model.catalog[h],'unknown package '..h)end end
   return model:mutate(function()model.cfg=cfg;model.cfg.presets=model.cfg.presets or{}end)
  end,refresh)
  action(p,'reset','Reset extra preload plan','恢复额外预载方案',function()return model:reset('plan')end,refresh)
  local info=row(p,'summary','Selected / targets / expanded resources','已选包／目标／展开资源数');info.empty=true
  info.readonly_text=function()return#S.keys(model.cfg.selected)..' / '..#S.keys(model.cfg.targets)..' / '..tostring(model.report.resources or'?')end
  for _,h in ipairs(S.keys(model.cfg.targets))do local pkg=model.catalog[h];local r=row(p,'target_'..h,'Target '..h,'加载目标 '..h);r.empty=true;r.readonly_text=pkg.path~=''and pkg.path or h end
 end
 p.custom_modified=function()return next(model.cfg.selected)~=nil end
 p.custom_reset=function()local ok,why=model:reset('plan');refresh();return ok,why end
 p.custom_preset=function(what,n)local ok,why=model:preset(what,'plan',n,'plan');refresh();return ok,why end
 p.ensure_rows=function()if p.model_version~=model.version then refresh();p.model_version=model.version end end
 refresh()
end
return M
