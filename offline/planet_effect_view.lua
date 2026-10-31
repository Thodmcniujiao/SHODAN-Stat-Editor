local P=require('planet_effects')
local D=require('demolition')
local N=require('network_proxy')
local Steam=require('steam_integration')
local M={by_index={},titles={}}
function M.translate_name(name,lang)local f=M.titles[name];return f and f(lang)end
function M.status_revision()
 local s=M.model and M.model:status();local n=N.status()
 return tostring(s and s.updated or 0)..':'..tostring(n.updated)..':'..N.revision..':'..Steam.revision
end
function M.build(c,page,txt,definitions,model)
 M.model=model;M.by_index={};M.titles={}
 local names={}
 for debug,p in pairs(require('planet_data').planets or{})do
  names[tonumber(D.hex(D.hash_resource(debug)):sub(1,8),16)]=p
 end
 function M.name(index)
  local ref=model.planets[index];local p=ref and names[ref.settingsHash]
  return p and txt(p.en,p.zhs,p.zht)or txt('Planet #','星球 #')..tostring(index)
 end
 local function row(p,id,label,section)
  local r={id=id,label=id,label_of=label,parts={},storage='u32',min=0,max=1,custom_value=function()return 0 end,
   component='PlanetEffectAssignment',component_of=function()return txt('Planet effect assignments','星球词条分配')end,
   section=section or'assign',section_of=function()return section=='planned'and txt('Requested effects','已指定的词条（计划）')or txt('Assign effects to this planet','向本星球添加词条')end}
  p.rows[#p.rows+1]=r;return r
 end
 local function info(p,id,label,value,section)
  local r=row(p,id,label,section);r.empty=true;r.readonly_text=value;r.tip_of=function()return{label(),type(value)=='function'and value()or tostring(value)}end;return r
 end
 local function action(p,id,label,button,fn,section)
  local r=row(p,id,label,section);r.custom_text=button;r.custom_action=fn;return r
 end
 local function flag(p,id,label,get,set,original)
  local r=row(p,id,label);r.storage='flag'
  original=original==true
  r.custom_value=function(default)return(default and original or not default and get())and 1 or 0 end
  r.custom_change=function(v)return set(v>=.5)end;r.custom_reset=function()return set(original)end;return r
 end
 for _,ref in ipairs(P.data.planets)do
  local index=ref.index
  local function name(lang)
   local n=names[ref.settingsHash];local zh=lang=='zh-Hans'or lang=='zh-Hant'
   return string.format('%03d · %s',index,n and(zh and(lang=='zh-Hant'and n.zht or n.zhs)or n.en)or('Planet #'..index))
  end
  local p=page('PlanetEffectAssignments',name('en'),'planet-effect-assignment/'..index)
  p.planet_index=index;M.by_index[index]=p;M.titles[p.name]=name
  p.search=p.search..' '..name('zh-Hans')..' '..name('zh-Hant')
  p.search_extra=function()return table.concat(model:effective(index),' ')end
  p.custom_modified=function()return model:changed(index)end
  p.custom_reset=function()return model:reset(index)end
  p.on_select=function()return model:select(index)end
  p.note_of=function()return txt('Network-layer interception: local HTTPS response rewrite; no game-file writes.',
   '网络层劫持：本机 HTTPS 代理改写战况响应；保留原有词条，不写入游戏文件。')end
  p.ensure_rows=function()
   if p.rows_built and p.assignment_revision==model.revision then return end
   p.rows_built,p.assignment_revision,p.rows=true,model.revision,{}
   info(p,'planet_index',function()return txt('Target planet index','目标星球编号')end,tostring(index)..' · '..M.name(index))
   info(p,'mode',function()return txt('Application','生效方式')end,
    txt('Network-layer interception; rewrites Status received by this client only.',
     '网络层劫持 · 改写本机收到的战况响应；无需点击“写入游戏”。'))
   info(p,'proxy_runtime',function()return txt('Local proxy service','本机代理服务')end,function()return N.status().message end)
   action(p,'proxy_start',function()return txt('Bundled proxy core','内置代理核心')end,function()return txt('Start proxy','启动代理')end,N.start)
   action(p,'proxy_stop',function()return txt('Stop local proxy','停止本机代理')end,function()return txt('Stop proxy','停止代理')end,N.stop)
   action(p,'proxy_trust',function()return txt('Local CA (current user only)','本机 CA（仅当前用户）')end,
    function()return N.status().trusted and txt('Certificate trusted','证书已信任')or txt('Trust local CA','信任本机 CA')end,N.trust)
   action(p,'proxy_launch_option',function()return txt('Steam launch option (preserve existing flags)','Steam 启动选项（保留原参数）')end,
    function()return txt('Copy launch option','复制启动选项')end,function()return c.copy_text(N.launch_option())end)
   info(p,'proxy_bridge',function()return txt('Steam bridge','Steam 接入检查')end,function()
    return Steam.status().message end)
   action(p,'steam_repair',function()return txt('Repair Steam integration','自动修复 Steam 接入')end,
    function()return txt('Repair now','立即修复接入')end,Steam.repair)
   action(p,'steam_restart',function()return txt('Restart Steam normally (exit games first)','正常重启 Steam（先退出游戏）')end,
    function()return txt('Restart Steam and repair','重启 Steam 并修复')end,Steam.restart_and_repair)
   action(p,'steam_restore',function()return txt('Restore original Steam options','恢复 Steam 原启动选项')end,
    function()return txt('Restore (disable auto repair)','恢复并关闭自动修复')end,Steam.restore)
   flag(p,'assignment_master',function()return txt('Enable planet effect assignments','启用星球词条分配（总开关）')end,
    function()return model.cfg.enabled end,function(v)return model:master(v)end)
   action(p,'choose_effect',function()return txt('Browse effects and add','浏览并选择词条')end,function()return txt('Choose effect','选择词条 →')end,
    function()local ok,why=model:select(index);if not ok then return nil,why end;return c.open_page(definitions.by_id[M.last_effect or 1202])end)
   local input=row(p,'add_ids',function()return txt('Add effect ID(s)','直接添加词条 ID')end)
   input.input_text=function()return''end;input.custom_text=function()return txt('Enter ID(s), e.g. 1202','输入 ID，例如 1202；可逗号分隔')end
   input.custom_edit=function(text)
    text=text:gsub('，',','):gsub('[,;]',' ')
    local ids={};for token in text:gmatch('%S+')do
     if not token:match('^%d+$')then return nil,txt('Use decimal effect IDs separated by commas.','请输入十进制词条 ID，用逗号分隔。')end
     ids[#ids+1]=tonumber(token)
    end
    return model:add(index,ids)
   end
   local icons=flag(p,'include_icons',function()return txt('Also add verified paired icons','同时添加已确认配对的图标')end,
    function()return model:target(index).include_icons end,function(v)return model:icons(index,v)end,true)
   icons.tip_of=function()return{txt('Only gameplay ID -> verified icon ID. Selecting an icon alone never adds its gameplay effect.',
    '只为生效 ID 补上已确认的图标 ID；单独选择图标不会自动添加生效词条。')}end
   info(p,'proxy_status',function()return txt('Last proxy status','上次代理处理状态')end,function()
    local s=model:status();return s and s.message or txt('Proxy not observed; start the supplied proxy first.','尚未收到代理状态；请先启动附带代理。')
   end)
   local t=model:target(index)
   for _,id in ipairs(t.effects)do
    local effect=definitions.by_id[id]
    action(p,'remove_'..id,function()return definitions.translate_name(effect.name,c.lang())or effect.name end,function()return txt('Remove from plan','从计划移除')end,
     function()return model:remove(index,id)end,'planned')
   end
   if #t.effects==0 then info(p,'empty',function()return txt('No requested effects','尚未指定词条')end,txt('Use Choose effect or enter an ID above.','点击“选择词条”，或在上方输入 ID。'),'planned')end
   info(p,'effective',function()return txt('IDs to append (including icons)','计划追加 ID（含配对图标）')end,
    function()local a=model:effective(index);return #a==0 and'—'or table.concat(a,', ')end,'planned')
   if model.error then info(p,'error',function()return txt('Plan error','计划错误')end,model.error)end
  end
 end
end
function M.effect_rows(c,p,id,make_row,txt)
 local model=M.model;if not model then return end
 local target=make_row(p,'assignment_target',function()return txt('Target planet / return','目标星球／返回')end,'Planet assignment')
 target.custom_value=function()return 0 end
 target.custom_text=function()local at=model.cfg.selected_planet;return at<0 and txt('Choose planet →','选择星球 →')or M.name(at)..' (#'..at..') →'end
 target.custom_action=function()local at=model.cfg.selected_planet;return c.open_page(M.by_index[at>=0 and at or 0])end
 local add=make_row(p,'assign_to_planet',function()return txt('Assign this effect to the selected planet','将本词条添加到目标星球')end,'Planet assignment')
 add.custom_value=function()return 0 end;add.custom_text=function()
  for _,chosen in ipairs(model:target(model.cfg.selected_planet).effects)do if chosen==id then return txt('Already in plan','已在计划中')end end
  return txt('Add this effect','添加本词条')
 end
 add.custom_action=function()
  local at=model.cfg.selected_planet
  if at<0 then return nil,txt('Choose a target planet first.','请先选择目标星球。')end
  local ok,why=model:add(at,id);if ok then M.last_effect=id end;return ok,why
 end
end
return M
