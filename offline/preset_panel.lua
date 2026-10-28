-- Dedicated preset workspace. No game navigation, component categories or stat rows.
local V=require('component_view')
local M={}
function M.draw(c)
 local P,ui,W,H=c.presets,c.ui,c.W,c.H
 local text,button,rect,outline,region=c.text,c.button,c.rect,c.outline,c.region
 local GOLD,WHITE,MUTED=c.GOLD,c.WHITE,c.MUTED
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 text(tx('Preset editor','预设编辑模式'),18,12,24,GOLD)
 button('workspace_back',tx('Back to editor','返回编辑'),W-156,10,140,32,true)
 local x=16
 for _,scope in ipairs(P.scopes)do
  button('preset_scope:'..scope.id,V.pick(c.lang(),scope.label),x,52,148,32,true,P.scope==scope.id);x=x+156
 end
 local order,chosen=P.full_order(),P.chosen()
 local rows=math.max(1,math.floor((H-236)/30));ui.preset_rows=rows
 local last=math.max(1,#order-rows+1);ui.fpage=math.max(1,math.min(ui.fpage,last))
 for i=1,rows do
  local id=order[ui.fpage+i-1];if not id then break end
  local p=P.list()[id];local y=100+(i-1)*30
  if id==chosen then rect(16,y,318,28,c.selected)
  elseif ui.hover=='fslot:'..id then rect(16,y,318,28,c.hover)end
  text(p.name,24,y+5,16,id==chosen and GOLD or WHITE,238)
  text(tostring(P.count(p)),326,y+5,14,MUTED,60,true)
  region('fslot:'..id,16,y,318,28)
 end
 if #order==0 then
  text(tx('No named presets yet','还没有命名预设'),24,108,17,MUTED,300)
  text(tx('Save the current changes below.','在下方保存当前修改。'),24,140,15,MUTED,300)
 end
 button('fpage:prev','<',16,H-144,40,30,ui.fpage>1)
 text(tx('Presets: ','共 ')..#order..tx('',' 个预设'),70,H-136,16,MUTED,214)
 button('fpage:next','>',294,H-144,40,30,ui.fpage<last)
 button('fpreset:new',tx('+ Save as new preset','＋保存为新预设'),16,H-104,318,30,P.can_capture())
 rect(343,96,2,H-166,c.line)
 local x0,p=356,chosen and P.list()[chosen]
 if p then
  local editing=ui.editing and ui.editing.n==chosen
  if editing then
   rect(x0-4,96,420,34,c.input);outline(x0-4,96,420,34,GOLD)
   text(ui.editing.text..'_',x0+4,102,20,WHITE,404)
   button('name:ok',tx('OK','确定'),x0+426,96,70,34,true)
   button('name:cancel',tx('Cancel','取消'),x0+502,96,100,34,true)
  else text(p.name,x0,102,22,GOLD,W-x0-20)end
  local sure=ui.confirm and ui.confirm.n==chosen and ui.confirm.kind
  button('fpreset:load',tx('Load preset','载入预设'),x0,146,112,32,true)
  button('fpreset:save',sure=='save'and tx('Again to overwrite','再次点击覆盖')or tx('Replace with current changes','用当前修改覆盖'),x0+122,146,238,32,P.can_capture(),sure=='save')
  button('fpreset:rename',tx('Rename','重命名'),x0+370,146,110,32,true)
  button('fpreset:delete',sure=='delete'and tx('Again to delete','再次点击删除')or tx('Delete','删除'),x0+490,146,110,32,true,sure=='delete')
  text(tx('Current category: ','当前类别可保存：')..P.current_count()..tx(' entries',' 项'),x0,196,15,MUTED,W-x0-24)
  local help
  if p.scope=='loadout'then help=tx('Loading stages the equipment; return to its page to Write save.','载入后暂存配装；返回配装页点击“写入存档”。')
  elseif p.kind=='patch'then help=tx('Imported partial preset: merges only the recorded parameters.','旧单项方案：只合并此方案记录的参数。')
  else help=tx('Loading replaces this category. Use the bottom Write button to apply.','载入会替换当前类别的修改；点击底部写入按钮应用。')end
  text(help,x0,222,15,MUTED,W-x0-24)
  rect(x0,254,W-x0-18,1,c.line)
  text(tx('Saved contents','已保存内容'),x0,270,18,WHITE)
  local y=306;local details=P.details(p);local room=math.floor((H-140-y)/26)
  for i,entry in ipairs(details)do
   if i>room then text(tx('More entries: ','另有 ')..(#details-room)..tx('',' 项'),x0,y,15,MUTED);break end
   text(entry.label,x0,y,16,WHITE,W-x0-154)
   text(entry.value,W-26,y,15,MUTED,140,true);y=y+26
  end
  if #details==0 then text(tx('No parameter changes saved.','没有保存参数改动。'),x0,y,16,MUTED,W-x0-24)end
 else
  text(tx('Keep changes under a name','按名称管理修改方案'),x0,104,22,GOLD)
  text(tx('Choose a category, then save the current changes as a new preset.','选择类别，然后将当前修改保存为新预设。'),x0,152,17,WHITE,W-x0-24)
  text(tx('Existing presets and legacy slots are imported automatically.','已有预设与旧快捷槽会自动导入，原文件保留。'),x0,188,15,MUTED,W-x0-24)
 end
 rect(16,H-64,W-32,1,c.line)
 text(tx('Enter: load · Insert: new · F2: rename · Del: delete · Esc: back','Enter 载入 · Insert 新建 · F2 重命名 · Del 删除 · Esc 返回'),18,H-54,14,MUTED,W-36)
 local message=ui.message and ui.message.text or c.status and c.status()or tx('Presets are stored in preset_library.json.','预设保存在 preset_library.json。')
 text(message,18,H-30,14,MUTED,W-36)
end
return M
