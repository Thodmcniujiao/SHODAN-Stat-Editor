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
 text(tx('Global presets · all parameters, demolition, equipment and preload','全局预设 · 所有参数、拆毁、配装与预载方案'),18,60,17,GOLD,W-208)
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
   text(edit.text..'_',x0+4,102,20,WHITE,rw-192)
   button('name:ok',tx('OK','确定'),W-186,96,70,34,true)
   button('name:cancel',tx('Cancel','取消'),W-108,96,90,34,true)
  else text(p.name,x0,102,22,GOLD,rw)end
  local sure=ui.confirm and ui.confirm.n==chosen and ui.confirm.kind
  button('fpreset:load',tx('Load preset','载入预设'),x0,146,112,32,true)
  button('fpreset:save',sure=='save'and tx('Again to overwrite','再次点击覆盖')or tx('Replace with current changes','用当前修改覆盖'),x0+122,146,238,32,P.can_capture(),sure=='save')
  button('fpreset:rename',tx('Rename','重命名'),x0+370,146,110,32,true)
  button('fpreset:delete',sure=='delete'and tx('Again to delete','再次点击删除')or tx('Delete','删除'),x0+490,146,110,32,true,sure=='delete')
  button('pmenu:move',tx('Group: ','分组：')..(p.group~=''and p.group or tx('Ungrouped','未分组')),x0,190,rw,28,true,toggle('move'))
  local describing=edit and edit.kind=='description'and edit.n==chosen
  rect(x0,226,rw,70,c.input)
  if describing then outline(x0,226,rw,70,GOLD)end
  local body=describing and(edit.text..'_')or p.description
  if not body or body==''then body=tx('Double-click here to add a description.','双击此处添加预设说明、用途或注意事项。')end
  local wrapped=lines(body,rw-20,15)
  ui.preset_description_last=math.max(1,#wrapped-2)
  local start=describing and math.max(1,#wrapped-2)or math.max(1,math.min(ui.preset_description_scroll or 1,ui.preset_description_last))
  for i=start,math.min(#wrapped,start+2)do text(wrapped[i],x0+8,234+(i-start)*19,15,describing and WHITE or MUTED,rw-16)end
  if #wrapped>3 then text(tostring(start)..'/'..#wrapped,W-24,282,11,MUTED,50,true)end
  if not describing then region('fpreset:description',x0,226,rw,70)end
  if describing then
   text(tx('Enter: save · Shift+Enter: newline · Esc: cancel','Enter 保存 · Shift+Enter 换行 · Esc 取消'),x0,310,13,MUTED,rw-178)
   button('name:ok',tx('Save','保存'),W-186,302,70,28,true)
   button('name:cancel',tx('Cancel','取消'),W-108,302,90,28,true)
  else text(tx('Saved contents','已保存内容')..(p.kind=='patch'and tx(' (partial preset)','（部分方案）')or''),x0,310,18,WHITE)end
  local details=P.details(p)
  local top,bottom=360,H-120
  text(tx('Expand pages to view changes · original → saved','展开页面查看改动 · 原始值 → 预设值'),x0,340,14,MUTED,rw)
  -- Scroll by complete entries so headings and two-line parameter rows stay intact.
  local tail,total=#details,0
  for i=#details,1,-1 do
   if total+details[i].height>bottom-top then break end
   total=total+details[i].height;tail=i
  end
  ui.preset_detail_last=math.max(1,tail)
  ui.preset_detail_scroll=math.max(1,math.min(ui.preset_detail_scroll or 1,ui.preset_detail_last))
  local y,shown=top,0
  for i=ui.preset_detail_scroll,#details do
   local item=details[i];if y+item.height>bottom then break end
   if item.kind=='parameter'then
    local entry=item.entry;local left=x0+28;local width=rw-28
    text(entry.entity,left,y+2,14,MUTED,width)
    text(entry.label..' ['..entry.id..']',left,y+22,15,WHITE,width*.60)
    local display=(entry.baseline and(entry.baseline..' → ')or'')..entry.value..' *'
    text(display,W-24,y+22,16,GOLD,width*.36,true)
    rect(left,y+46,width,1,c.line)
   else
    local main=item.kind=='page';local left=x0+(main and 0 or 16)
    local marker=item.count>0 and(item.expanded and'v  'or'>  ')or'   '
    local label=marker..item.label..(item.count>0 and(' *  ('..item.count..')')or'')
    button('ptree_'..item.kind..':'..item.id,label,left,y,rw-(left-x0),item.height-4,item.count>0,item.expanded,item.count>0 and(main and GOLD or WHITE)or MUTED)
   end
   y=y+item.height;shown=shown+1
  end
  ui.preset_detail_rows=math.max(1,shown)
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
 end
 if menu_list then
  local room=math.max(1,math.floor((H-menu_y-108)/28));local last=math.max(1,#menu_list-room+1)
  ui.preset_menu_scroll=math.max(1,math.min(ui.preset_menu_scroll or 1,last));ui.preset_menu_last=last
  region('pmenu:dismiss',0,90,W,H-160)
  rect(menu_x-4,menu_y-4,menu_w+8,math.min(#menu_list,room)*28+8,c.input,970)
  outline(menu_x-4,menu_y-4,menu_w+8,math.min(#menu_list,room)*28+8,GOLD,971)
  for i=1,room do
   local entry=menu_list[ui.preset_menu_scroll+i-1];if not entry then break end
   local key=menu_kind=='group'and'pgroup_id:'or'pmove:'
   button(key..entry.id,entry.label..(entry.count and entry.count>0 and' *'or''),menu_x,menu_y+(i-1)*28,menu_w,26,true,false,nil,972)
  end
 end
 if edit and edit.kind=='group'then
  rect(x0-8,94,rw+8,132,c.input,980);outline(x0-8,94,rw+8,132,GOLD,981)
  text(tx('New group folder (use / for nested groups)','新建分组文件夹（可用 / 创建子分组）'),x0,104,17,GOLD,rw,false,983)
  text(edit.text..'_',x0,140,20,WHITE,rw,false,983)
  button('name:ok',tx('Create','创建'),x0,180,100,30,true,false,nil,982)
  button('name:cancel',tx('Cancel','取消'),x0+110,180,100,30,true,false,nil,982)
 end
 rect(16,H-64,W-32,1,c.line)
 text(tx('Enter: load · Insert: new · F2: rename · Del: delete · Esc: back','Enter 载入 · Insert 新建 · F2 重命名 · Del 删除 · Esc 返回'),18,H-54,14,MUTED,W-36)
 local message=ui.message and ui.message.text or tx('Preset folder: ','预设文件夹：')..tostring(P.directory or'Presets')
 text(message,18,H-30,14,MUTED,W-36)
end
return M
