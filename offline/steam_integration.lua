-- Native Steam discovery and guarded updates; no injection or UI automation.
local ffi=require('ffi')
local F=require('preset_files')
local Paths=require('user_paths')
local Options=require('steam_launch_options')
local I=require('install')
for _,d in ipairs({
 'int32_t RegGetValueA(void *key,const char *sub,const char *value,uint32_t flags,void *type,void *data,uint32_t *size);',
 'void *ShellExecuteW(void *window,const uint16_t *verb,const uint16_t *file,const uint16_t *parameters,const uint16_t *directory,int show);',
})do pcall(ffi.cdef,d)end
local api=ffi.load('advapi32');local shell=ffi.load('shell32')
local user=ffi.cast('void *',ffi.cast('intptr_t',-2147483647))
local M={revision=0,enabled=true}
local last_target,manager,last_poll,restart
local function wide(s,cp)
 local n=ffi.C.MultiByteToWideChar(cp or 0,0,s,-1,nil,0);local w=ffi.new('uint16_t[?]',math.max(n,1))
 if n>0 then ffi.C.MultiByteToWideChar(cp or 0,0,s,-1,w,n)end;return w
end
local function utf8(s)
 local w=wide(s);local n=ffi.C.WideCharToMultiByte(65001,0,w,-1,nil,0,nil,nil);local b=ffi.new('char[?]',math.max(n,1))
 if n>0 then ffi.C.WideCharToMultiByte(65001,0,w,-1,b,n,nil,nil)end;return ffi.string(b)
end
function M.bridge_path()return utf8(Paths.root..'/app/network/steam_bridge.exe'):gsub('/','\\')end
function M.launch_option()return'"'..M.bridge_path()..'" %command%'end
local function steam_root()
 local root,n=ffi.new('char[32768]'),ffi.new('uint32_t[1]',32768)
 if api.RegGetValueA(user,'Software\\Valve\\Steam','SteamPath',2,nil,root,n)~=0 then return end
 return ffi.string(root):gsub('\\','/'):gsub('/+$','')
end
function M.running()
 local snap=ffi.C.CreateToolhelp32Snapshot(2,0)
 if snap==nil or ffi.cast('intptr_t',snap)==-1 then return true end -- unknown is not safe to write
 local e=ffi.new('host_process_entry');e.size=ffi.sizeof(e);local found=false
 if ffi.C.Process32FirstW(snap,e)~=0 then repeat
  local chars={};for n=0,259 do local ch=tonumber(e.exe[n]);if ch==0 then break end;chars[#chars+1]=ch<128 and string.char(ch)or'?'end
  if table.concat(chars):lower()=='steam.exe'then found=true;break end
 until ffi.C.Process32NextW(snap,e)==0 else found=true end
 ffi.C.CloseHandle(snap);return found
end
local function resolve()
 local root=steam_root();if not root then return nil,'未找到 Steam 安装目录。'end
 local account,n=ffi.new('uint32_t[1]'),ffi.new('uint32_t[1]',4)
 local ok=api.RegGetValueA(user,'Software\\Valve\\Steam\\ActiveProcess','ActiveUser',16,nil,account,n)==0
 local id=ok and tonumber(account[0])or 0
 if id==0 and not M.running()then
  local users=F.read(root..'/config/loginusers.vdf')
  if users then
   local recent,why=Options.recent_account(users);if not recent then return nil,why end
   id=tonumber(recent)
  elseif last_target and Options.normalized(last_target.root)==Options.normalized(root)then return last_target end
 end
 if id==0 then return nil,'未找到 Steam 当前账户；请登录 Steam 后再检查。'end
 local target={root=root,account=tostring(id),path=root..'/userdata/'..tostring(id)..'/config/localconfig.vdf',bridge=M.bridge_path()}
 last_target=target;return target
end
local function recognize(path)
 -- Migration of a preceding build before a journal existed: require this binary,
 -- not just an executable with the same name. Journaled deleted paths also work.
 if not Options.normalized(path):match('/app/network/steam_bridge%.exe$')then return false end
 local w=wide(path,65001);local n=ffi.C.WideCharToMultiByte(0,0,w,-1,nil,0,nil,nil)
 local b=ffi.new('char[?]',math.max(n,1));if n>0 then ffi.C.WideCharToMultiByte(0,0,w,-1,b,n,nil,nil)end
 local old=F.read(ffi.string(b));local current=F.read(Paths.root..'/app/network/steam_bridge.exe')
 return old~=nil and current~=nil and old==current
end
local function commit(path,before,after,guard)
 local temp=path..'.shodan-tmp'
 if not guard()then return nil,'Steam 已启动或账户已变化，未写入配置。'end
 local h=ffi.C.CreateFileW(F.path_w(path),0x80000000,4,nil,3,0x80,nil) -- read + share delete; exclude writers
 if h==nil or ffi.cast('intptr_t',h)==-1 then return nil,'无法独占 Steam 配置，未覆盖。'end
 local function locked()
  local size=ffi.new('int64_t[1]');local done=ffi.new('uint32_t[1]')
  if ffi.C.GetFileSizeEx(h,size)==0 or tonumber(size[0])~=#before then return nil,'Steam 配置已变化，请重试。'end
  local bytes=ffi.new('uint8_t[?]',math.max(1,#before))
  if ffi.C.ReadFile(h,bytes,#before,done,nil)==0 or tonumber(done[0])~=#before or ffi.string(bytes,#before)~=before then return nil,'Steam 配置已变化，请重试。'end
  local ok,why=F.write(temp,after);if not ok then return nil,why end
  if not guard()then return nil,'Steam 已启动或账户已变化，未写入配置。'end
  return true
 end
 local call,ok,why=pcall(locked);ffi.C.CloseHandle(h)
 -- Windows can refuse replacement while the destination is open, including
 -- handles sharing DELETE. Release the validation lock and recheck just before
 -- the single atomic rename. Never truncate Steam's destination in place.
 if call and ok then
  if not guard()or F.read(path)~=before then ok,why=nil,'Steam 或配置已变化，未写入配置。'
  else
   ok,why=F.move(temp,path)
   if ok and F.read(path)~=after then ok,why=nil,'Steam 配置回读不一致；请重新检查。'end
  end
 end
 F.remove(temp)
 if not call then return nil,'Steam 配置操作失败：'..tostring(ok)end
 return ok,why
end
M.commit=commit
local function instance()
 if not manager then manager=Options.new{fs=F,home=Paths.home,resolve=resolve,running=M.running,recognize=recognize,commit=commit,
  mkdir=function(path)I.mkdirs(path);return F.mkdir(path)end}end
 return manager
end
local function publish(s)
 local old=M.current
 if not old or old.state~=s.state or old.message~=s.message then M.revision=M.revision+1 end
 M.current=s;return s
end
local function native_start(root,args)
 local result=shell.ShellExecuteW(nil,wide('open'),wide(root..'/steam.exe'),wide(args,65001),wide(root),0)
 return tonumber(ffi.cast('intptr_t',result))>32
end
function M.poll(enabled,force)
 local changed=M.enabled~=(enabled~=false);M.enabled=enabled~=false
 local now=os.time();if not force and not changed and last_poll==now then return M.current end;last_poll=now
 local model=instance()
 if restart then
  if not M.running()then
   local job=restart;restart=nil
   local s=job.restore and model:restore()or model:repair()
   -- Reopen Steam even if configuration failed; don't leave the user's client closed.
   if not native_start(job.root,'-silent')then s={state='error',message='配置处理完成，但未能重启 Steam；请手动启动。'}end
   return publish(s)
  elseif now>=restart.deadline then restart=nil;return publish{state='error',message='Steam 未在 45 秒内退出；未强制结束，也未写入配置。'}
  else return publish{state='restarting',message='正在等待 Steam 正常退出，完成后自动处理并重启。'}end
 end
 local ok,s=pcall(model.poll,model,M.enabled)
 return publish(ok and s or{state='error',message='Steam 接入检查失败：'..tostring(s)})
end
function M.status()return M.current or publish(instance():run('ensure',false))end
function M.ready()return instance():run('ensure',false).state=='ready'end
function M.repair()
 local s=instance():repair();last_poll=nil;publish(s)
 return s.state=='ready'or s.state=='waiting',s.message
end
function M.restore()
 if M.disable_auto then M.disable_auto()end;M.enabled=false
 local s=instance():restore();last_poll=nil;publish(s)
 return s.state=='restored'or s.state=='waiting',s.message
end
function M.restart_and_repair()
 if I.game_running()then return nil,'游戏正在运行，请先正常退出游戏。'end
 local target,why=resolve();if not target then return nil,why end
 local inspection=instance():run(instance().pending=='restore'and'restore'or'ensure',false)
 if inspection.state=='conflict'or inspection.state=='error'or inspection.state=='unavailable'then publish(inspection);return nil,inspection.message end
 if not M.running()then
  if instance().pending=='restore'then return M.restore()end
  return M.repair()
 end
 if not native_start(target.root,'-shutdown')then return nil,'无法请求 Steam 正常退出。'end
 restart={root=target.root,deadline=os.time()+45,restore=instance().pending=='restore'}
 publish{state='restarting',message='正在等待 Steam 正常退出，完成后自动处理并重启。'}
 return true
end
return M
