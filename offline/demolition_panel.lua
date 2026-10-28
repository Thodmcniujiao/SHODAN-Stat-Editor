local D=require('demolition')
local P={};P.__index=P
local WORDS={
 en={title='Entity Demolition',components='Entity Components',search='Search name, path or hash',all='All targets',editable='Editable',changed='Changed',
  entity='ECS entity',unit='Scene Unit',normal='Normal',hit='Direct hits',stage='Entry',base='Baseline',value='Threshold',
  entries='Entry 1/2/3 = slots 0/1/2; not health phases. Unused slots hidden.',
  reset='Reset row',reset_entity='Reset target',reset_all='Reset all demolition edits',prev='Previous',next='Next',
  empty='No matching targets',unavailable='No editable destruction configuration',inherit='inherits normal hits until overridden',
  save='Saved. Install into the game to apply.',integer='Enter a whole number from 0 to 4294967295.',
  disabled='Changes are off in Settings. Turn them on to edit.',
  isolated='Private templates and cloned Unit references isolate ECS entities.',
  runtime='Private template IDs and Unit aliases still need an in-game compatibility test.',
  keys='Enter: edit   Delete: reset row   PgUp/PgDn: targets   Ctrl+F: search',
  loading='Destruction data is unavailable',shared='entities use the original Unit',
  default='Default',override='Override',stale='saved entries are unavailable in this build'},
 ['zh-Hans']={title='实体拆毁',components='实体组件',search='搜索名称 路径或哈希',all='全部目标',editable='可编辑',changed='已修改',
  entity='ECS 实体',unit='场景 Unit',normal='普通命中',hit='直击覆盖',stage='破坏记录',base='读取基线',value='拆毁阈值',
  entries='记录 1/2/3 对应配置槽位 0/1/2；隐藏未使用项，不代表三段血条。',
  reset='恢复此项',reset_entity='恢复此实体',reset_all='清除全部拆毁修改',prev='上一页',next='下一页',
  empty='没有匹配的目标',unavailable='没有可编辑的拆毁配置',inherit='当前继承普通命中 输入数值后建立独立直击覆盖',
  save='已保存 点击安装到游戏后生效',integer='请输入 0 至 4294967295 的整数',
  disabled='设置中的修改开关已关闭，请开启后编辑。',
  isolated='使用私有模板及 Unit 资源别名 隔离不同 ECS 实体',
  runtime='新增模板编号和 Unit 别名仍需要游戏内兼容性验证',
  keys='Enter 编辑  Delete 恢复此项  PgUp/PgDn 切换目标  Ctrl+F 搜索',
  loading='拆毁数据不可用',shared='个实体共用原始 Unit',
  default='继承基线',override='独立覆盖',stale='条旧配置在当前版本不可用'},
}
local C={back={255,12,15,19},panel={255,22,27,34},active={255,38,51,64},text={255,238,242,246},
 border={255,69,86,101},hover={255,46,63,79},muted={255,153,171,184},gold={255,255,213,0},cyan={255,103,210,220},warn={255,255,150,60}}
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function backspace(s)return s:gsub('[%z\1-\127\194-\244][\128-\191]*$','')end
function P.new(model,options)
 local self=setmetatable({model=model,options=options,values={},stale={},filter='',mode='editable',
  selected=1,scroll=0,row=1,focus='search',buffer='',keys={},version=1,hits={},message=''},P)
 local saved=D.load_overrides(options.path)
 for id,values in pairs(saved)do
  for key,v in pairs(values)do
   local single={[id]={[key]=v}}
   local dest=pcall(function()model:validate(single)end)and self.values or self.stale
   dest[id]=dest[id]or{};dest[id][key]=v
  end
 end
 self:refilter();return self
end
function P:tr(key)
 local lang=self.options.lang and self.options.lang()or'en'
 local words=WORDS[lang]or(lang=='zh-Hant'and WORDS['zh-Hans'])or WORDS.en
 return words[key]or WORDS.en[key]or key
end
function P:refilter()
 local old=self.list and self.list[self.selected]
 local words={};for w in self.filter:lower():gmatch('%S+')do words[#words+1]=w end
 self.list={}
 for _,t in ipairs(self.model.targets)do
  local include=self.mode=='all'or(self.mode=='changed'and self.values[t.id])or(self.mode=='editable'and not t.why and #t.levels>0)
  local label=self.options.tr and self.options.tr(t.name)or t.name
  local hay=(label..' '..t.name..' '..t.hash..' '..t.unit..' '..t.path):lower()
  for _,w in ipairs(words)do if not hay:find(w,1,true)then include=false;break end end
  if include then self.list[#self.list+1]=t end
 end
 self.selected=math.min(math.max(self.selected,1),math.max(#self.list,1))
 if old then for i,t in ipairs(self.list)do if t.id==old.id then self.selected=i;break end end end
 self.scroll=math.max(0,math.min(self.scroll,math.max(#self.list-20,0)));self.version=self.version+1
end
function P:value(t,l)
 if self.options.enabled and not self.options.enabled()then return l.value end
 local own=self.values[t.id]or{}
 if own[l.key]~=nil then return own[l.key]end
 if l.inherited and own[l.level..':normal']~=nil then return own[l.level..':normal']end
 return l.value
end
function P:persist()
 local all={};for id,v in pairs(self.stale)do all[id]=v end
 for id,v in pairs(self.values)do all[id]=v end
 local ok,why=D.save_overrides(self.options.path,all)
 self.message=ok and self:tr('save')or tostring(why)
 self.version=self.version+1
 if ok and self.options.changed then self.options.changed()end
 return ok,why
end
function P:set(id,key,value)
 local t=self.model.by_id[id];if not t then return nil,'target unavailable'end
 local l;for _,slot in ipairs(t.levels)do if slot.key==key then l=slot end end
 if not l or t.why then return nil,'stage unavailable'end
 if value~=nil then
  if self.options.enabled and not self.options.enabled()then self.message=self:tr('disabled');self.version=self.version+1;return nil,self.message end
  local ok=pcall(function()self.model:validate({[id]={[key]=value}})end)
  if not ok then self.message=self:tr('integer');self.version=self.version+1;return nil,self.message end
 end
 local before=self.values[id];local slots={};for k,v in pairs(before or{})do slots[k]=v end
 self.values[id]=slots;slots[key]=value
 if not next(self.values[id])then self.values[id]=nil end
 local ok,why=self:persist();if not ok then self.values[id]=before end;return ok,why
end
function P:overrides(enabled)return enabled==false and{}or self.values end
function P:commit()
 if self.focus~='number'then return true end
 local t=self.list[self.selected];local l=t and t.levels[self.row]
 if not l then self.focus=nil;return true end
 local v=tonumber(self.buffer)
 if not self.buffer:match('^%d+$')or not v then self.message=self:tr('integer');self.version=self.version+1;return nil end
 local ok=self:set(t.id,l.key,v);if ok then self.focus=nil end;return ok
end
function P:edit(index)
 if self.options.enabled and not self.options.enabled()then self.message=self:tr('disabled');self.version=self.version+1;return end
 local t=self.list[self.selected];local l=t and t.levels[index]
 if not l or t.why then return end
 self.row=index;self.focus='number';self.buffer=string.format('%.0f',self:value(t,l));self.replace_input=true;self.version=self.version+1
end
function P:activate(shim)
 shim.take_typed();self.keys={};self.focus='search';self.version=self.version+1
end
function P:update(shim)
 local language=self.options.lang and self.options.lang()or'en'
 if self.language~=language then self.language=language;self:refilter()end
 local function pressed(vk)
  local down=shim.focused()and shim.key_down(vk)
  local yes=down and not self.keys[vk];self.keys[vk]=down;return yes
 end
 local x,y=shim.cursor();local s=shim.h/1080
 local hover
 if shim.focused()and x and y then
  for _,hit in ipairs(self.hits)do
   if x/s>=hit.x and x/s<hit.x+hit.w and y/s>=hit.y and y/s<hit.y+hit.h then
    hover=hit.action..':'..tostring(hit.value);break
   end
  end
 end
 if hover~=self.hover then self.hover=hover;self.version=self.version+1 end
 local click=pressed(1)
 if click and x and y then
  x,y=x/s,y/s
  for _,hit in ipairs(self.hits)do
   if x>=hit.x and x<hit.x+hit.w and y>=hit.y and y<hit.y+hit.h then
    if hit.action~='edit'and self.focus=='number'and not self:commit()then break end
    if hit.action=='component_sub'then
     self.focus=nil;self.version=self.version+1
     if self.options.open_component_sub then self.options.open_component_sub(hit.value)end
    elseif hit.action=='search'then self.focus='search';self.version=self.version+1
    elseif hit.action=='mode'then self.mode=hit.value;self.selected=1;self.scroll=0;self:refilter()
    elseif hit.action=='select'then self.selected=hit.value;self.row=1;self.focus=nil;self.version=self.version+1
    elseif hit.action=='edit'then self:edit(hit.value)
    elseif hit.action=='reset'then local t=self.list[self.selected];local l=t and t.levels[hit.value];if l then self:set(t.id,l.key,nil)end
    elseif hit.action=='reset_entity'then local t=self.list[self.selected];if t then self.values[t.id]=nil;self:persist()end
    elseif hit.action=='reset_all'then
     if self.confirm_reset then self.values,self.stale={},{};self.confirm_reset=nil;self:persist();self:refilter()
     else self.confirm_reset=true;self.message=self:tr('reset_all')..' ?';self.version=self.version+1 end
    elseif hit.action=='page'then self.scroll=math.max(0,math.min(self.scroll+hit.value,math.max(#self.list-20,0)));self.version=self.version+1 end
    break
   end
  end
 end
 if pressed(0x0D)then
  if self.focus=='number'then self:commit()
  elseif self.focus~='search'then self:edit(self.row)end
 end
 if pressed(0x1B)then self.focus=nil;self.confirm_reset=nil;self.version=self.version+1 end
 local find=pressed(0x46)
 if shim.key_down(0x11)and find then
  if self.focus~='number'or self:commit()then self.focus='search';self.version=self.version+1 end
 end
 if pressed(0x08)then
  if self.focus=='search'then self.filter=backspace(self.filter);self:refilter()
  elseif self.focus=='number'then self.buffer=self.replace_input and''or backspace(self.buffer);self.replace_input=false;self.version=self.version+1 end
 end
 if pressed(0x2E)and self.focus~='search'then
  if self.focus=='number'then self.buffer='';self.replace_input=false;self.version=self.version+1
  else local t=self.list[self.selected];local l=t and t.levels[self.row];if l then self:set(t.id,l.key,nil)end end
 end
 local function move(delta)
  if self.focus=='number'and not self:commit()then return end
  self.selected=math.max(1,math.min(self.selected+delta,#self.list));self.row=1
  self.scroll=math.max(0,math.min(self.selected-1,math.max(#self.list-20,0)));self.version=self.version+1
 end
 if pressed(0x21)then move(-20)end;if pressed(0x22)then move(20)end
 if self.focus~='number'then if pressed(0x26)then move(-1)end;if pressed(0x28)then move(1)end end
 local typed=shim.take_typed()
 if typed~=''then
  if self.focus=='search'then self.filter=self.filter..typed;self:refilter()
  elseif self.focus=='number'then
   typed=typed:gsub('%D','')
   if typed~=''then self.buffer=(self.replace_input and''or self.buffer)..typed;self.replace_input=false;self.version=self.version+1 end
  end
 end
end
function P:draw(shim)
 local s=shim.h/1080;self.hits={}
 local texting=false
 local function fill(x,y,w,h,c)
  if texting then shim.flush();texting=false end
  shim.fill(x*s,y*s,(x+w)*s,(y+h)*s,c)
 end
 local function text(v,x,y,size,c,bold)
  shim.text_top(tostring(v),x*s,y*s,size*s,c or C.text,bold);texting=true
 end
 local function box(x,y,w,h,border,inside)
  fill(x,y,w,h,border);fill(x+1,y+1,w-2,h-2,inside)
 end
 local function fit(v,width,size)
  v=tostring(v)
  if shim.text_width(v,size*s)<=width*s then return v end
  while #v>0 and shim.text_width(v..'...',size*s)>width*s do v=backspace(v)end
  return v..'...'
 end
 local function button(label,x,y,w,action,value,on,font_size)
  font_size=font_size or 15
  local over=self.hover==action..':'..tostring(value)
  box(x,y,w,30,on and C.cyan or(over and C.cyan or C.border),over and C.hover or(on and C.active or C.panel))
  label=fit(label,w-12,font_size)
  local width=shim.text_width(label,font_size*s)/s;local height=shim.text_height(font_size*s)/s
  text(label,x+(w-width)/2,y+(30-height)/2,font_size,on and C.cyan or C.text)
  self.hits[#self.hits+1]={x=x,y=y,w=w,h=30,action=action,value=value}
 end
 fill(0,46,1060,986,C.back)
 local tabs=self.options.component_tabs and self.options.component_tabs()or{}
 text(self:tr(#tabs>0 and'components'or'title'),30,58,25,C.cyan,true)
 if #tabs>0 then
  local widths,total={},0
  for i,t in ipairs(tabs)do widths[i]=shim.text_width(t.label,14*s)/s+18;total=total+widths[i]end
  local scale=math.min(1,(1000-4*(#tabs-1))/total);local x=30
  for i,t in ipairs(tabs)do
   local width=widths[i]*scale
   button(t.label,x,94,width,'component_sub',t.id,t.selected,14*scale);x=x+width+4
  end
 else text(self:tr('isolated'),30,94,15,C.muted)end
 box(30,128,1000,36,self.focus=='search'and C.cyan or C.border,C.panel)
 local search=fit(self.filter~=''and self.filter or self:tr('search'),970,17)
 text(search,40,128+(36-shim.text_height(17*s)/s)/2,17,self.filter~=''and C.text or C.muted)
 if self.focus=='search'then
  local width=self.filter==''and 0 or shim.text_width(search,17*s)/s
  fill(40+width,136,1,20,C.cyan)
 end
 self.hits[#self.hits+1]={x=30,y=128,w=1000,h=36,action='search'}
 button(self:tr('all'),30,174,100,'mode','all',self.mode=='all')
 button(self:tr('editable'),138,174,100,'mode','editable',self.mode=='editable')
 button(self:tr('changed')..' '..count(self.values),246,174,130,'mode','changed',self.mode=='changed')
 text(#self.list..' / '..#self.model.targets,397,181,15,C.muted)
 fill(30,220,390,700,C.panel)
 local slots=20
 for row=1,slots do
  local index=self.scroll+row;local t=self.list[index]
  if t then
   local y=226+(row-1)*34
   if index==self.selected then fill(34,y,382,32,C.active)end
   local name=self.options.tr and self.options.tr(t.name)or t.name
   local label=(self.values[t.id]and'* 'or'')..name
   text(fit(label,366,15),42,y+5,15,t.why and C.muted or C.text)
   self.hits[#self.hits+1]={x=34,y=y,w=382,h=32,action='select',value=index}
  end
 end
 button(self:tr('prev'),30,932,105,'page',-20)
 button(self:tr('next'),145,932,105,'page',20)
 text(math.min(self.scroll+1,#self.list)..' - '..math.min(self.scroll+20,#self.list)..' / '..#self.list,263,940,14,C.muted)
 local t=self.list[self.selected]
 if not t then text(self:tr('empty'),450,230,19,C.muted)
 else
  text(fit(self.options.tr and self.options.tr(t.name)or t.name,575,21),445,222,21,C.text,true)
  text((t.scope=='entity'and self:tr('entity')or self:tr('unit'))..'  '..t.hash,445,258,15,C.muted)
  text('Unit  '..t.unit,445,284,15,C.muted)
  text('Settings  '..tostring(t.index or'--')..'   '..t.shared..' '..self:tr('shared'),445,310,15,C.muted)
  text(fit(t.path,575,13),445,337,13,C.muted)
  text(fit(self:tr('entries'),580,12),445,358,12,C.muted)
  if t.why or #t.levels==0 then
   text(self:tr('unavailable'),445,390,19,C.warn)
   text(fit(t.why or'',570,13),445,425,13,C.muted)
  else
   text(self:tr('stage'),445,380,16,C.muted)
   text(self:tr('base'),705,380,15,C.muted)
   text(self:tr('value'),810,380,15,C.muted)
   for i,l in ipairs(t.levels)do
    local y=416+(i-1)*66
    fill(442,y-5,586,57,i==self.row and C.active or C.panel)
    local label=self:tr('stage')..' '..(l.level+1)..' '..self:tr(l.hit and'hit'or'normal')
    text(label,450,y,16,C.text)
    text(l.value,710,y,16,C.muted)
    local v=self.focus=='number'and self.row==i and(self.buffer..'_')or string.format('%.0f',self:value(t,l))
    box(802,y-4,118,32,self.focus=='number'and self.row==i and C.cyan or C.border,C.back)
    text(fit(v,106,18),808,y,18,C.gold)
    self.hits[#self.hits+1]={x=802,y=y-4,w=118,h=32,action='edit',value=i}
    button(self:tr('reset'),930,y-2,93,'reset',i)
    local own=(self.values[t.id]or{})[l.key]~=nil
    text(fit(own and self:tr('override')or(l.inherited and self:tr('inherit')or self:tr('default')),480,16),450,y+25,13,C.muted)
   end
  end
  button(self:tr('reset_entity'),445,850,180,'reset_entity')
  button(self:tr('reset_all'),637,850,385,'reset_all')
 end
 local enabled=not self.options.enabled or self.options.enabled()
 text(fit(enabled and self.message or self:tr('disabled'),1000,15),30,980,15,C.warn)
 if count(self.stale)>0 then text(count(self.stale)..' '..self:tr('stale'),445,899,14,C.warn)end
 text(self:tr('keys'),445,932,13,C.muted)
 text(fit(self:tr('runtime'),575,13),445,952,13,C.warn)
 shim.flush()
end
return P
