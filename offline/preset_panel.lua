-- Preset browser: physical folder groups and read-only editor-page previews.
local V=require('component_view')
local M={}
local function lines(text,width,size)
 local out,line,units={},'',0
 for ch in (text..'\n'):gmatch('[%z\1-\127\194-\244][\128-\191]*')do
  local n=ch:byte()<128 and .55 or 1
  if ch=='\n'or units+n>width/size then out[#out+1]=line;line='';units=0 end
  if ch~='\n' then line=line..ch;units=units+n end
 end
 return out
end
function M.draw(c)
 local P,ui,W,H=c.presets,c.ui,c.W,c.H
 local text,button,rect,outline,region=c.text,c.button,c.rect,c.outline,c.region
 local GOLD,WHITE,MUTED=c.GOLD,c.WHITE,c.MUTED
 local function tx(en,cn)return V.pick(c.lang(),{en,cn,cn})end
 local function toggle(key)return ui.preset_menu==key end
 text(tx('Preset editor','预设编辑模式'),18,12,24,GOLD)
 text(tx('Global presets · all parameters, demolition, equipment and preload','全局预设 · 所有参数、拆毁、配装与预载方案'),18,60,17,GOLD,W-320)
 local merge=ui.preset_merge
 button('fpreset:refresh',tx('Refresh','刷新'),W-298,52,102,32,not ui.editing and not merge)
 button('preset_folder',tx('Open preset folder','打开预设文件夹'),W-188,52,172,32,true)
 local groups=P.groups();local group_label=groups[1].label
 for _,g in ipairs(groups)do if g.id==ui.preset_group then group_label=g.label end end
 button('pgroup:prev','<',16,100,38,30,true)
 button('pmenu:group',group_label,60,100,230,30,true,toggle('group'))
 button('pgroup:next','>',296,100,38,30,true)
 button('pgroup:new',tx('+ New group','＋新建分组'),16,138,318,28,true)
 local order,chosen=P.full_order(),P.chosen()
 local rows=math.max(1,math.floor((H-304)/30));ui.preset_rows=rows
 local last=math.max(1,#order-rows+1);ui.fpage=math.max(1,math.min(ui.fpage,last))
 for i=1,rows do
  local id=order[ui.fpage+i-1];if not id then break end
  local p=P.list()[id];local y=178+(i-1)*30
  if id==chosen then rect(16,y,318,28,c.selected)
  elseif ui.hover=='fslot:'..id then rect(16,y,318,28,c.hover)end
  text(p.name,24,y+5,16,id==chosen and GOLD or WHITE,238)
  text(tostring(P.count(p)),326,y+5,14,MUTED,60,true)
  region('fslot:'..id,16,y,318,28)
 end
 if #order==0 then text(tx('No presets in this group','此分组暂无预设'),24,186,17,MUTED,300)end
 button('fpage:prev','<',16,H-144,40,30,ui.fpage>1)
 text(tx('Presets: ','共 ')..#order..tx('',' 个预设'),70,H-136,16,MUTED,214)
 button('fpage:next','>',294,H-144,40,30,ui.fpage<last)
 button('fpreset:new',tx('+ Save as new preset','＋保存为新预设'),16,H-104,318,30,P.can_capture())
 rect(343,96,2,H-166,c.line)
 local x0,p=356,chosen and P.list()[chosen];local rw=W-x0-18
 local edit=ui.editing
 local menu_list,menu_x,menu_y,menu_w,menu_kind
 if p then
  if edit and edit.n==chosen and not edit.kind then
   rect(x0-4,96,rw-178,34,c.input);outline(x0-4,96,rw-178,34,GOLD)
   if c.draw_input then c.draw_input(edit,x0+4,102,20,WHITE,rw-192,false,953,x0-4,96,rw-178,34,64)
   else text(require('text_edit').show(edit,64),x0+4,102,20,WHITE,rw-192)end
   button('name:ok',tx('OK','确定'),W-186,96,70,34,true)
   button('name:cancel',tx('Cancel','取消'),W-108,96,90,34,true)
  else text(p.name,x0,102,22,GOLD,rw)end
  local sure=ui.confirm and ui.confirm.n==chosen and ui.confirm.kind
  button('fpreset:load',tx('Load preset','载入预设'),x0,146,112,32,true)
  button('fpreset:save',sure=='save'and tx('Again to overwrite','再次点击覆盖')or tx('Replace with current changes','用当前修改覆盖'),x0+122,146,238,32,P.can_capture(),sure=='save')
  button('fpreset:rename',tx('Rename','重命名'),x0+370,146,110,32,true)
  button('fpreset:delete',sure=='delete'and tx('Again to delete','再次点击删除')or tx('Delete','删除'),x0+490,146,110,32,true,sure=='delete')
  button('pmenu:move',tx('Group: ','分组：')..(p.group~=''and p.group or tx('Ungrouped','未分组')),x0,190,rw-180,28,not merge,toggle('move'))
  button('fpreset:merge',merge and tx('Merging…','合并中…')or tx('Merge into…','合并到其他预设'),W-190,190,172,28,not edit,merge~=nil)
  local describing=edit and edit.kind=='description'and edit.n==chosen
  if merge then
   -- merge bar (instead of the description): what is picked, the target, conflicts, preview / back
   rect(x0,226,rw,70,c.input);outline(x0,226,rw,70,GOLD)
   local target=merge.target and P.list()[merge.target]
   text(merge.plan and tx('Preview: nothing is written until you confirm.','预览：确认前不会修改任何预设。')
    or tx('Tick pages, groups or parameters to merge · picked: ','勾选要合并的页面、分组或参数 · 已选 ')..P.merge_count()..tx('',' 项'),x0+8,232,15,GOLD,rw-16)
   button('pmenu:merge_target',tx('Into: ','目标：')..(target and target.name or tx('choose a preset','选择预设')),x0+8,260,rw-416,28,not merge.plan,toggle('merge_target'))
   button('pmerge:keep',merge.keep and tx('Conflicts: keep target','冲突：保留目标值')or tx('Conflicts: overwrite','冲突：覆盖目标值'),W-418,260,170,28,not merge.plan,merge.keep)
   if merge.plan then
    button('pmerge:apply',tx('Confirm merge','确认合并'),W-240,260,120,28,merge.plan.changes>0)
    button('pmerge:back',tx('Back','返回选择'),W-112,260,90,28,true)
   else
    button('pmerge:preview',tx('Preview','预览合并'),W-240,260,120,28,P.merge_count()>0 and target~=nil)
    button('pmerge:cancel',tx('Exit','退出'),W-112,260,90,28,true)
   end
   text(merge.plan and tx('Merge preview','合并预览')or tx('Choose contents to merge','选择要合并的内容'),x0,310,18,WHITE)
  else
  rect(x0,226,rw,70,c.input)
  if describing then outline(x0,226,rw,70,GOLD)end
  if describing and c.draw_multiline then
   local total,start=c.draw_multiline(edit,x0+8,234,19,3,15,rw-20,953)
   ui.preset_description_last=math.max(1,total-2)
   if total>3 then text(tostring(start)..'/'..total,W-24,282,11,MUTED,50,true)end
  else
   local body=describing and(edit.text..'_')or p.description
   if not body or body==''then body=tx('Double-click here to add a description.','双击此处添加预设说明、用途或注意事项。')end
   local wrapped,caret_row
   if describing then wrapped,caret_row=require('text_edit').lines(edit,rw-20,15)else wrapped=lines(body,rw-20,15)end
   ui.preset_description_last=math.max(1,#wrapped-2)
   local start=describing and math.max(1,(caret_row or #wrapped)-2)or math.max(1,math.min(ui.preset_description_scroll or 1,ui.preset_description_last))
   for i=start,math.min(#wrapped,start+2)do text(wrapped[i],x0+8,234+(i-start)*19,15,describing and WHITE or MUTED,rw-16)end
   if #wrapped>3 then text(tostring(start)..'/'..#wrapped,W-24,282,11,MUTED,50,true)end
  end
  if not describing then region('fpreset:description',x0,226,rw,70)end
  if describing then
   text(tx('Enter: save · Shift+Enter: newline · Esc: cancel','Enter 保存 · Shift+Enter 换行 · Esc 取消'),x0,310,13,MUTED,rw-178)
   button('name:ok',tx('Save','保存'),W-186,302,70,28,true)
   button('name:cancel',tx('Cancel','取消'),W-108,302,90,28,true)
  else text(tx('Saved contents','已保存内容')..(p.kind=='patch'and tx(' (partial preset)','（部分方案）')or''),x0,310,18,WHITE)end
  end
  local details=P.details(p)
  local top,bottom=360,H-120
  text(merge and merge.plan and tx('Target value → merged value','目标原值 → 合并后的值')
   or merge and tx('[x] whole · [-] partly · [ ] not picked · a package or planet merges whole','[x] 全选 · [-] 部分 · [ ] 未选 · 预载包与星球方案整体合并')
   or tx('Expand pages to view changes · original → saved · double-click a parameter to open it','展开页面查看改动 · 原始值 → 预设值 · 双击参数跳转到对应页面'),x0,340,14,MUTED,rw)
  if merge and merge.plan then
   -- the preview list, scrolled like the details
   local list=P.merge_lines();local room=math.max(1,math.floor((bottom-top)/22))
   ui.preset_detail_last=math.max(1,#list-room+1)
   ui.preset_detail_scroll=math.max(1,math.min(ui.preset_detail_scroll or 1,ui.preset_detail_last))
   local tones={head=GOLD,add=WHITE,conflict=c.WARN or GOLD,kept=MUTED,blocked=c.WARN or MUTED,muted=MUTED}
   for i=0,room-1 do local l=list[ui.preset_detail_scroll+i];if not l then break end
    text(l.text,x0+(l.tone=='head'and 0 or 8),top+i*22,15,tones[l.tone]or WHITE,rw-8)
   end
   ui.preset_detail_rows=room
  else
  -- Scroll by complete entries so headings and two-line parameter rows stay intact.
  local tail,total=#details,0
  for i=#details,1,-1 do
   if total+details[i].height>bottom-top then break end
   total=total+details[i].height;tail=i
  end
  ui.preset_detail_last=math.max(1,tail)
  ui.preset_detail_scroll=math.max(1,math.min(ui.preset_detail_scroll or 1,ui.preset_detail_last))
  local y,shown=top,0
  local function pick(kind,id,x,at)
   local state=P.merge_state(kind,id)
   button('pmerge_pick:'..kind..':'..id,state=='all'and'[x]'or state=='some'and'[-]'or'[ ]',x,at,30,24,state~=nil,state=='all')
  end
  for i=ui.preset_detail_scroll,#details do
   local item=details[i];if y+item.height>bottom then break end
   if item.kind=='parameter'then
    local entry=item.entry;local left=x0+28;local width=rw-28
    if merge then
     if entry.pick then pick('entry',entry.pick,left,y+12)end
     left=left+36;width=width-36
    end
    text(entry.entity,left,y+2,14,MUTED,width)
    text(entry.label..' ['..entry.id..']',left,y+22,15,WHITE,width*.60)
    local display=(entry.baseline and(entry.baseline..' → ')or'')..entry.value..' *'
    text(display,W-24,y+22,16,GOLD,width*.36,true)
    rect(left,y+46,width,1,c.line)
    if not merge then region('pdetail:'..i,left,y,width,46)end
   else
    local main=item.kind=='page';local left=x0+(main and 0 or 16)
    if merge and item.count>0 then pick(item.kind,item.id,left,y+2);left=left+36 end
    local marker=item.count>0 and(item.expanded and'v  'or'>  ')or'   '
    local label=marker..item.label..(item.count>0 and(' *  ('..item.count..')')or'')
    button('ptree_'..item.kind..':'..item.id,label,left,y,rw-(left-x0),item.height-4,item.count>0,item.expanded,item.count>0 and(main and GOLD or WHITE)or MUTED)
   end
   y=y+item.height;shown=shown+1
  end
  ui.preset_detail_rows=math.max(1,shown)
  end
  button('pdetail_scroll:prev','<',x0,H-108,32,28,ui.preset_detail_scroll>1)
  text(tx('Changes: ','改动 ')..P.count(p)..tx(' · Snapshot entries: ',' 项 · 快照记录 ')..P.saved_count(p)..tx('',' 项'),x0+42,H-100,14,MUTED,rw-84)
  button('pdetail_scroll:next','>',W-50,H-108,32,28,ui.preset_detail_scroll<ui.preset_detail_last)

 else
  text(tx('Keep changes under a name','按名称管理修改方案'),x0,104,22,GOLD,rw)
  text(tx('Save all current changes together as one global preset.','将所有页面的当前修改一起保存为一个全局预设。'),x0,152,17,WHITE,rw)
  text(tx('Folders inside Presets become groups automatically.','Presets 下的子文件夹会自动成为分组。'),x0,188,15,MUTED,rw)
 end
 if toggle('group')or toggle('move')then
  menu_list={};for _,g in ipairs(groups)do if toggle('group')or g.id~='*'then menu_list[#menu_list+1]=g end end
  menu_x=toggle('group')and 60 or x0;menu_y=toggle('group')and 134 or 222
  menu_w=toggle('group')and 274 or rw;menu_kind=ui.preset_menu
 elseif toggle('merge_target')and merge then
  menu_list=P.merge_targets();menu_x,menu_y,menu_w,menu_kind=x0+8,292,rw-416,'merge_target'
  if #menu_list==0 then menu_list={{id='',label=tx('No other preset','没有其他预设')}}end
 end
 if menu_list then
  local room=math.max(1,math.floor((H-menu_y-108)/28));local last=math.max(1,#menu_list-room+1)
  ui.preset_menu_scroll=math.max(1,math.min(ui.preset_menu_scroll or 1,last));ui.preset_menu_last=last
  region('pmenu:dismiss',0,90,W,H-160)
  rect(menu_x-4,menu_y-4,menu_w+8,math.min(#menu_list,room)*28+8,c.input,970)
  outline(menu_x-4,menu_y-4,menu_w+8,math.min(#menu_list,room)*28+8,GOLD,971)
  for i=1,room do
   local entry=menu_list[ui.preset_menu_scroll+i-1];if not entry then break end
   local key=menu_kind=='group'and'pgroup_id:'or menu_kind=='merge_target'and'pmerge_target:'or'pmove:'
   button(key..entry.id,entry.label..(entry.count and entry.count>0 and' *'or''),menu_x,menu_y+(i-1)*28,menu_w,26,true,false,nil,972)
  end
 end
 if edit and edit.kind=='group'then
  rect(x0-8,94,rw+8,132,c.input,980);outline(x0-8,94,rw+8,132,GOLD,981)
  text(tx('New group folder (use / for nested groups)','新建分组文件夹（可用 / 创建子分组）'),x0,104,17,GOLD,rw,false,983)
  if c.draw_input then c.draw_input(edit,x0,140,20,WHITE,rw-16,false,983,x0-4,134,rw,32,64)
  else text(edit.text..'_',x0,140,20,WHITE,rw,false,983)end
  button('name:ok',tx('Create','创建'),x0,180,100,30,true,false,nil,982)
  button('name:cancel',tx('Cancel','取消'),x0+110,180,100,30,true,false,nil,982)
 end
 rect(16,H-64,W-32,1,c.line)
 text(tx('Enter: load · Insert: new · F2: rename · Del: delete · Esc: back','Enter 载入 · Insert 新建 · F2 重命名 · Del 删除 · Esc 返回'),18,H-54,14,MUTED,W-36)
 local message=ui.message and ui.message.text or tx('Preset folder: ','预设文件夹：')..tostring(P.directory or'Presets')
 text(message,18,H-30,14,MUTED,W-36)
end
return M
