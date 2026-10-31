-- Targeted KeyValues edits and a portable transaction journal. No Steam/native calls.
local J=require('json_data')
local M={}
local function normalized(s)return s:gsub('\\','/'):gsub('/+','/'):lower()end
M.normalized=normalized
function M.quote(s)
 return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\r','\\r'):gsub('\n','\\n'):gsub('\t','\\t')..'"'
end
local function parse(raw)
 assert(type(raw)=='string'and #raw<=8*1024*1024,'Steam 配置缺失或过大。')
 local at=raw:sub(1,3)=='\239\187\191'and 4 or 1
 local function token()
  while at<=#raw do
   if raw:sub(at,at):match('%s')then at=at+1
   elseif raw:sub(at,at+1)=='//'then at=(raw:find('\n',at+2,true)or #raw)+1
   else break end
  end
  if at>#raw then return end
  local start=at;local c=raw:sub(at,at)
  if c=='{'or c=='}'then at=at+1;return{value=c,start=start,finish=at-1,brace=true}end
  if c=='"'then
   at=at+1;local out={}
   while at<=#raw do
    c=raw:sub(at,at);at=at+1
    if c=='"'then return{value=table.concat(out),start=start,finish=at-1}end
    if c=='\\'then
     local nextc=raw:sub(at,at);local escaped=({['\\']='\\',['"']='"',n='\n',r='\r',t='\t'})[nextc]
     if escaped then c=escaped;at=at+1 end
    end
    out[#out+1]=c
   end
   error('Steam 配置含未闭合字符串。')
  end
  while at<=#raw and not raw:sub(at,at):match('[%s{}]')do at=at+1 end
  return{value=raw:sub(start,at-1),start=start,finish=at-1}
 end
 local function object(depth)
  assert(depth<64,'Steam 配置嵌套过深。')
  local result={}
  while true do
   local key=token()
   if not key then assert(depth==0,'Steam 配置缺少结束括号。');return result end
   if key.brace then assert(key.value=='}'and depth>0,'Steam 配置括号不匹配。');result.close=key.start;return result end
   local value=assert(token(),'Steam 配置缺少值。')
   local node={key=key.value,start=key.start,vs=value.start,ve=value.finish}
   if value.brace then assert(value.value=='{','Steam 配置缺少值。');node.children=object(depth+1);node.close=node.children.close
   else node.value=value.value end
   result[#result+1]=node
  end
 end
 return object(0)
end
local function child(nodes,key)
 local found
 for _,n in ipairs(nodes)do if n.key:lower()==key:lower()then assert(not found,'Steam 配置目标含重复键：'..key);found=n end end
 return found
end
function M.recent_account(raw)
 local ok,value=pcall(function()
  local users=assert(child(parse(raw),'users'),'Steam 账户目录缺少 users。')
  assert(users.children,'Steam 账户目录格式不兼容。')
  local selected
  for _,entry in ipairs(users.children)do
   local recent=entry.children and child(entry.children,'MostRecent')
   if recent and recent.value=='1'then
    assert(not selected,'Steam 最近账户不唯一，未自动选择。')
    assert(entry.key:match('^%d+$')and #entry.key==17 and entry.key>='76561197960265728','Steam 账户编号格式不兼容。')
    local account=0
    for digit in entry.key:gmatch('.')do account=(account*10+tonumber(digit))%4294967296 end
    assert(account>0,'Steam 账户编号无效。');selected=string.format('%.0f',account)
   end
  end
  return assert(selected,'未找到 Steam 最近登录账户。')
 end)
 if ok then return value end
 return nil,tostring(value):gsub('^.-:%d+: ','')
end
function M.inspect(raw)
 local ok,result=pcall(function()
  local nodes=parse(raw)
  for _,key in ipairs({'UserLocalConfigStore','Software','Valve','Steam','apps'})do
   local n=assert(child(nodes,key),'Steam 配置缺少路径：'..key)
   nodes=assert(n.children,'Steam 配置目标不是分组：'..key)
  end
  local app=child(nodes,'553850')
  if app then assert(app.children,'Steam 的 553850 条目不是分组。')end
  local option=app and child(app.children,'LaunchOptions')
  if option then assert(option.value,'Steam 启动选项不是字符串。')end
  return{raw=raw,apps=nodes,app=app,option=option,value=option and option.value or'',present=option~=nil}
 end)
 if ok then return result end
 return nil,tostring(result):gsub('^.-:%d+: ','')
end
function M.replace(doc,value,present)
 local raw,n=doc.raw,doc.option
 if n then
  if present then return raw:sub(1,n.vs-1)..M.quote(value)..raw:sub(n.ve+1)end
  return raw:sub(1,n.start-1)..raw:sub(n.ve+1)
 end
 if not present then return raw end
 local nl=raw:find('\r\n',1,true)and'\r\n'or'\n'
 local at=doc.app and doc.app.close or doc.apps.close
 local insert=doc.app and('"LaunchOptions"\t\t'..M.quote(value))or('"553850"'..nl..'\t\t\t\t\t{'..nl..'\t\t\t\t\t\t"LaunchOptions"\t\t'..M.quote(value)..nl..'\t\t\t\t\t}')
 return raw:sub(1,at-1)..'\t'..insert..nl..'\t\t\t\t\t'..raw:sub(at)
end
local function prefix(value)
 local path,tail=value:match('^%s*"([^"]+)"%s+%%command%%(.*)$')
 if not path then path,tail=value:match('^%s*(%S+)%s+%%command%%(.*)$')end
 if path then return path,tail end
end
function M.merge(value,bridge,record,recognize)
 local tail=value;local owned=false;local count=0
 while true do
  local path,rest=prefix(tail)
  if not path then break end
  if normalized(path)~=normalized(bridge)and not(record and normalized(path)==normalized(record.bridge))and not(recognize and recognize(path))then
   return nil,'现有启动选项包含其他包装器，未自动覆盖。'
  end
  count=count+1;if count>8 then return nil,'Steam 桥接前缀过多，未自动覆盖。'end;owned=true;tail=rest:gsub('^%s+','')
 end
 if tail:find('%%command%%')then
  local rest=tail:match('^%s*%%command%%(.*)$')
  if rest and not rest:find('%%command%%')then tail=rest:gsub('^%s+','')
  else return nil,'现有启动选项包含不明 %command% 结构，未自动覆盖。'end
 end
 local output='"'..bridge..'" %command%'..(tail~=''and' '..tail or'')
 -- Keep existing whitespace/spelling if already a single correct prefix.
 local path=prefix(value)
 if count==1 and path and normalized(path)==normalized(bridge)then output=value end
 return output,nil,owned,tail
end
function M.new(c)
 local self={status={state='checking',message='正在检查 Steam 接入。'},pending=nil}
 local function state(kind,message,extra)
  local s=extra or{};s.state,s.message=kind,message;self.status=s;return s
 end
 local function read_record(target)
  local path=c.home..'/SteamLaunchOptions/'..target.account..'.json'
  local raw=c.fs.read(path)
  if not raw then return nil,path end
  local ok,r=pcall(J.decode,raw)
  if not(ok and type(r)=='table'and r.version==1 and r.account==target.account and type(r.bridge)=='string'
   and type(r.original)=='string'and type(r.present)=='boolean'and type(r.applied)=='string'
   and type(r.config_path)=='string'and normalized(r.config_path)==normalized(target.path))then return false,path,'Steam 启动选项备份损坏或目录已变化，未自动覆盖。'end
  return r,path
 end
 local function save_record(path,record)
  local ok,why=c.mkdir(c.home..'/SteamLaunchOptions');if not ok then return nil,why end
  local temp=path..'.tmp';ok,why=c.fs.write(temp,J.encode(record,true))
  if ok then ok,why=c.fs.move(temp,path)end
  if not ok then c.fs.remove(temp)end
  return ok,why
 end
 function self:run(operation,write)
  local target,why=c.resolve()
  if not target then return state('unavailable',why or'未找到 Steam 当前账户。')end
  local raw=c.fs.read(target.path);local doc;doc,why=M.inspect(raw)
  if not doc then return state('error',why)end
  local record,record_path,record_error=read_record(target)
  if record==false then return state('error',record_error)end
  local output,err,owned,tail=M.merge(doc.value,target.bridge,record,c.recognize)
  if not output then return state('conflict',err)end
  local value,present=output,true
  if operation=='restore'then
   if not record then return state('unavailable','没有本程序保存的启动选项备份。')end
   if not owned then self.pending=nil;return state('restored','当前已无本程序桥接，保留现有参数。')end
   if doc.value==record.applied then value,present=record.original,record.present
   else
    value,present=tail,true
    if record.original:match('^%s*%%command%%')then value='%command%'..(tail~=''and' '..tail or'')end
   end
  end
  if not write then
   if operation=='ensure'and value==doc.value and doc.present then return state('ready','已接入当前构建。')end
   return state('needed','Steam 接入需要更新。')
  end
  if value==doc.value and present==doc.present and operation=='ensure'then
   if not record then
    record={version=1,account=target.account,config_path=target.path,bridge=target.bridge,original=tail,present=true,applied=doc.value}
    local ok;ok,why=save_record(record_path,record);if not ok then return state('error','保存原始启动选项失败：'..tostring(why))end
   end
   self.pending=nil;return state('ready','已接入当前构建。')
  end
  if c.running()then self.pending=operation;return state('waiting',operation=='restore'and'等待 Steam 退出后自动恢复原选项。'or'等待 Steam 退出后自动修复接入。')end
  if operation=='ensure'then
   if not record or not owned then record={version=1,account=target.account,config_path=target.path,original=doc.value,present=doc.present}end
   if owned and not record.bridge then record.original,record.present=tail,true end
   record.bridge,record.applied=target.bridge,value
   local ok;ok,why=save_record(record_path,record);if not ok then return state('error','保存原始启动选项失败：'..tostring(why))end
  end
  local updated=M.replace(doc,value,present)
  local function guard()
   if c.running()then return false end
   local latest=c.resolve()
   return latest and latest.account==target.account and normalized(latest.path)==normalized(target.path)
  end
  local ok;ok,why=c.commit(target.path,raw,updated,guard)
  if not ok then return state('error',why or'Steam 配置已变化，未覆盖；稍后重试。')end
  self.pending=nil
  return state(operation=='restore'and'restored'or'ready',operation=='restore'and'已恢复原选项，保留用户后续参数。'or'已自动修复 Steam 接入。')
 end
 function self:poll(enabled)
  if self.pending=='restore'then return self:run('restore',true)end
  if self.manual then local s=self:run('ensure',true);if s.state~='waiting'then self.manual=nil end;return s end
  if not enabled then self.pending=nil;local s=self:run('ensure',false);if s.state=='needed'then return state('disabled','自动修复已关闭；可点击“立即修复接入”。')end;return s end
  return self:run('ensure',true)
 end
 function self:repair()local s=self:run('ensure',true);self.manual=s.state=='waiting';return s end
 function self:restore()local s=self:run('restore',true);self.pending=s.state=='waiting'and'restore'or nil;return s end
 return self
end
return M
