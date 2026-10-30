-- A global preset spans every authoring store. Loading stages changes only;
-- the game's data/save files still use their explicit bottom Write actions.
local L=require('preset_library')
local M={}
local function copy(v)return L.copy(v)end
local function model(name)return rawget(_G,name)end
function M.capture(c)
 local data={version=2,game=c.game_settings()}
 local bridge=model('SHODAN_DEMOLITION_BRIDGE')
 if bridge then data.demolition={values=copy(bridge.panel.values),stale=copy(bridge.panel.stale)}end
 local preload=model('SHODAN_PRELOAD_MODEL')
 if preload then data.preload=copy(preload:snapshot())end
 local save=model('SHODAN_PLAYER_SAVE_MODEL')
 if save then
  local snapshot,why=save:snapshot()
  if snapshot then
   data.loadout=copy(snapshot)
   if save.read then
    data.loadout.baseline={};for key in pairs(snapshot.values or{})do data.loadout.baseline[key]=save:read(key,true)end
   end
  elseif save.count and save:count()>0 then return nil,why or'Could not capture edited equipment' end
 end
 return {values=copy(c.values(nil)),data=data,scope='global',kind='snapshot'}
end
local function demolition(bridge,snapshot,merge)
 local panel=bridge.panel
 local values,stale=merge and copy(panel.values)or{},merge and copy(panel.stale)or{}
 for id,slots in pairs(snapshot.values or{})do
  for key,value in pairs(slots)do
   assert(type(value)=='number'and value%1==0 and value>=0 and value<=4294967295,'Invalid demolition value')
   local valid=pcall(function()panel.model:validate({[id]={[key]=value}})end)
   local dest=valid and values or stale;dest[id]=dest[id]or{};dest[id][key]=value
  end
 end
 for id,slots in pairs(snapshot.stale or{})do stale[id]=stale[id]or{};for key,value in pairs(slots)do stale[id][key]=value end end
 local old,old_stale=panel.values,panel.stale;panel.values,panel.stale=values,stale
 local ok,why=panel:persist()
 if not ok then panel.values,panel.stale=old,old_stale;return nil,why end
 panel:refilter();return true
end
function M.apply(c,p)
 assert(p.scope=='global'and type(p.data)=='table'and p.data.version==2,'Unsupported global preset')
 local d=p.data
 local bridge,preload,save=model('SHODAN_DEMOLITION_BRIDGE'),model('SHODAN_PRELOAD_MODEL'),model('SHODAN_PLAYER_SAVE_MODEL')
 if (d.preload or d.legacy_preload)and not preload then return nil,'此全局预设包含预载方案，但预载编辑器不可用。'end
 if d.loadout and not save then return nil,'此全局预设包含存档配装，但存档编辑器不可用。'end
 if d.loadout and save.save==nil and save.paths then return nil,'请先在配装页读取目标存档，再载入这个全局预设。'end
 if d.demolition and not bridge then return nil,'此全局预设包含拆毁参数，但拆毁编辑器不可用。'end
 local before,why=M.capture(c);if not before then return nil,why end
 local function apply(payload,rollback)
  local data=payload.data;local patch=payload.kind=='patch'
  local ok,note=c.apply({scope='global',name=payload.name or'Global preset',kind=payload.kind,values=payload.values,data=data.game})
  assert(ok,note)
  if data.preload then local done,problem=preload:apply_snapshot(copy(data.preload));assert(done,problem)
  elseif data.legacy_preload then local item=data.legacy_preload;local done,problem=preload:apply_legacy_preset(item.legacy_key,copy(item.value));assert(done,problem)end
  if data.loadout then local done,problem=save:apply_snapshot(copy(data.loadout));assert(done,problem)
  elseif not patch and save and save.reset then local done,problem=save:reset();assert(done,problem)end
  if data.demolition then local done,problem=demolition(bridge,data.demolition,patch);assert(done,problem)end
  if c.sync then c.sync()end
  return note
 end
 local ok,note=pcall(apply,p)
 if not ok then
  local restored,err=pcall(apply,before,true)
  return nil,tostring(note)..(not restored and('；恢复原修改失败：'..tostring(err))or'；已保留载入前的修改。')
 end
 return true,note
end
function M.count(p)
 local d=p.data or{};local count=#(p.values or{})
 for _,key in ipairs({'stacks','own_off'})do for _ in pairs(d.game and d.game[key]or{})do count=count+1 end end
 for _,key in ipairs({'values','stale'})do for _,slots in pairs(d.demolition and d.demolition[key]or{})do for _ in pairs(slots)do count=count+1 end end end
 for _ in pairs(d.loadout and d.loadout.values or{})do count=count+1 end
 for _,key in ipairs({'edits','selected','targets','arrays'})do for _ in pairs(d.preload and d.preload[key]or{})do count=count+1 end end
 if d.legacy_preload then count=count+1 end
 return count
end
return M
