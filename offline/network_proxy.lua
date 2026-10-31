-- Portable native process control. No Python/PATH dependency or system proxy.
local ffi=require('ffi')
local F=require('preset_files')
local J=require('json_data')
local Paths=require('user_paths')
for _,d in ipairs({
 'typedef struct { uint32_t size,mask; void *window; const uint16_t *verb,*file,*parameters,*directory; int show; void *instance,*list; const uint16_t *class_name; void *class_key; uint32_t hotkey; void *icon,*process; } shodan_proxy_shell_info;',
 'int ShellExecuteExW(shodan_proxy_shell_info *info);',
 'uint32_t WaitForSingleObject(void *h,uint32_t ms);',
 'uint32_t GetProcessId(void *h);',
 'void *OpenProcess(uint32_t access,int inherit,uint32_t pid);',
 'int GetProcessTimes(void *h,uint32_t *created,uint32_t *exited,uint32_t *kernel,uint32_t *user);',
 'int QueryFullProcessImageNameW(void *h,uint32_t flags,uint16_t *path,uint32_t *size);',
 'int CloseHandle(void *h);',
 'int32_t RegGetValueA(void *key,const char *sub,const char *value,uint32_t flags,void *type,void *data,uint32_t *size);',
 'int CryptStringToBinaryA(const char *s,uint32_t n,uint32_t flags,uint8_t *out,uint32_t *size,uint32_t *skip,uint32_t *used);',
 'void *CertOpenStore(const void *provider,uint32_t encoding,void *crypt,uint32_t flags,const void *name);',
 'typedef struct { uint32_t encoding; const uint8_t *bytes; uint32_t size; void *info,*store; } shodan_proxy_cert;',
 'shodan_proxy_cert *CertEnumCertificatesInStore(void *store,shodan_proxy_cert *previous);',
 'int CertFreeCertificateContext(shodan_proxy_cert *context);',
 'int CertCloseStore(void *store,uint32_t flags);',
 'int CertAddEncodedCertificateToStore(void *store,uint32_t encoding,const uint8_t *bytes,uint32_t size,uint32_t mode,void *context);',
 'typedef struct { uint32_t size, usage, pid; uintptr_t heap; uint32_t module, threads, parent; int32_t base; uint32_t flags; uint16_t exe[260]; } host_process_entry;',
 'void *CreateToolhelp32Snapshot(uint32_t flags, uint32_t pid);',
 'int Process32FirstW(void *snapshot, host_process_entry *entry);',
 'int Process32NextW(void *snapshot, host_process_entry *entry);',
 'int TerminateProcess(void *process, uint32_t code);',
 'void Sleep(uint32_t ms);',
})do pcall(ffi.cdef,d)end
local shell=ffi.load('shell32');local crypt=ffi.load('crypt32')
local M={root=Paths.root,home=Paths.home,revision=0,port=8847}
local function wide(s)
 local n=ffi.C.MultiByteToWideChar(0,0,s,-1,nil,0);local w=ffi.new('uint16_t[?]',n)
 ffi.C.MultiByteToWideChar(0,0,s,-1,w,n);return w
end
local function utf8(w)
 local n=ffi.C.WideCharToMultiByte(65001,0,w,-1,nil,0,nil,nil);local s=ffi.new('char[?]',n)
 ffi.C.WideCharToMultiByte(65001,0,w,-1,s,n,nil,nil);return ffi.string(s)
end
local function decode(path)local raw=F.read(path);if raw then local ok,v=pcall(J.decode,raw);if ok and type(v)=='table'then return v end end end
local function quote(s)return'"'..s..'"'end
local function folder()return M.home..'/WarProxy'end
local function exe()return M.root..'/app/network/mitmdump.exe'end
local function certificate_bytes(pem)
 if not pem or pem==''then return end
 local size=ffi.new('uint32_t[1]')
 if crypt.CryptStringToBinaryA(pem,#pem,0,nil,size,nil,nil)==0 then return end
 local bytes=ffi.new('uint8_t[?]',size[0])
 if crypt.CryptStringToBinaryA(pem,#pem,0,bytes,size,nil,nil)==0 then return end
 return bytes,tonumber(size[0])
end
local function certificate()
 return certificate_bytes(F.read(folder()..'/mitmproxy-ca-cert.pem'))
end
local function root_store()
 return crypt.CertOpenStore(ffi.cast('const void *',10),0,nil,0x14000,wide('ROOT')) -- system W, current user, existing
end
local function cert_in_store(bytes,size)
 if not bytes then return false end
 local store=root_store();if store==nil then return false end
 local found=false;local context=nil
 while true do
  context=crypt.CertEnumCertificatesInStore(store,context);if context==nil then break end
  if context.size==size and ffi.string(context.bytes,size)==ffi.string(bytes,size)then found=true;crypt.CertFreeCertificateContext(context);break end
 end
 crypt.CertCloseStore(store,0);return found
end
function M.trusted()
 local bytes,size=certificate()
 return cert_in_store(bytes,size)
end
local function kill_mitmdump_processes(keep_pid)
 if rawget(_G,'TEST_WORK')then return end
 local snap=ffi.C.CreateToolhelp32Snapshot(2,0)
 if snap==nil or ffi.cast('intptr_t',snap)==-1 then return end
 local e=ffi.new('host_process_entry');e.size=ffi.sizeof(e)
 local handles={}
 local ok=ffi.C.Process32FirstW(snap,e)
 while ok~=0 do
  local name=utf8(e.exe):lower()
  if name=='mitmdump.exe'and e.pid~=keep_pid then
   local h=ffi.C.OpenProcess(0x100001,0,e.pid)
   if h~=nil then ffi.C.TerminateProcess(h,0);handles[#handles+1]=h end
  end
  ok=ffi.C.Process32NextW(snap,e)
 end
 ffi.C.CloseHandle(snap)
 for _,h in ipairs(handles)do ffi.C.WaitForSingleObject(h,400);ffi.C.CloseHandle(h)end
end
local function ensure_ca_files()
 if rawget(_G,'TEST_WORK')or M.trusted()then return end
 local rel_parent=M.root:gsub('\\','/'):match('^(.*)/[^/]+/SHODAN Stat Editor Offline$')
 if not rel_parent then return end
 local I=require('install')
 local stamps=I.list_files and{}or nil
 local find=ffi.new('host_find_data')
 local hfind=ffi.C.FindFirstFileA(rel_parent..'/*',find)
 local dirs={}
 if hfind~=nil and ffi.cast('intptr_t',hfind)~=-1 then
  repeat
   local dname=ffi.string(find.name)
   if dname~='.'and dname~='..'and bit.band(find.attributes,16)~=0 then dirs[#dirs+1]=dname end
  until ffi.C.Process32NextW and ffi.C.FindNextFileA(hfind,find)==0
  ffi.C.FindClose(hfind)
 end
 table.sort(dirs,function(a,b)return a>b end)
 for _,d in ipairs(dirs)do
  local wdir=rel_parent..'/'..d..'/SHODAN Stat Editor Offline/Data/WarProxy'
  local pem=F.read(wdir..'/mitmproxy-ca-cert.pem')
  local ca_key=F.read(wdir..'/mitmproxy-ca.pem')
  if pem and ca_key and cert_in_store(certificate_bytes(pem))then
   I.mkdirs(folder())
   for _,fn in ipairs({'mitmproxy-ca.pem','mitmproxy-ca-cert.pem','mitmproxy-ca.p12','mitmproxy-ca-cert.p12','mitmproxy-ca-cert.cer','mitmproxy-dhparam.pem'})do
    local content=F.read(wdir..'/'..fn)
    if content then F.write(folder()..'/'..fn,content)end
   end
   return
  end
 end
end
function M.trust()
 if M.trusted()then return true end
 local bytes,size=certificate();if not bytes then return nil,'代理尚未生成本机证书，请先启动代理。'end
 local store=root_store();if store==nil then return nil,'无法打开当前用户证书库。'end
 local ok=crypt.CertAddEncodedCertificateToStore(store,0x10001,bytes,size,1,nil)~=0
 crypt.CertCloseStore(store,0);M.revision=M.revision+1;M.cache_at=nil
 if not ok or not M.trusted()then return nil,'本机 CA 安装失败；未修改计算机级证书库。'end
 return true
end
local function process_matches(health)
 if not(health and type(health.pid)=='number'and type(health.started)=='string')then return false end
 local h=ffi.C.OpenProcess(0x101000,0,health.pid);if h==nil then return false end
 local made,exited,kernel,user=ffi.new('uint32_t[2]'),ffi.new('uint32_t[2]'),ffi.new('uint32_t[2]'),ffi.new('uint32_t[2]')
 local path,n=ffi.new('uint16_t[32768]'),ffi.new('uint32_t[1]',32768)
 local started
 if ffi.C.GetProcessTimes(h,made,exited,kernel,user)~=0 then started=tostring(ffi.new('uint64_t',made[1])*4294967296ULL+made[0]):gsub('ULL$','')end
 local matched=ffi.C.WaitForSingleObject(h,0)==258 and started==health.started
  and ffi.C.QueryFullProcessImageNameW(h,0,path,n)~=0
  and utf8(path):gsub('\\','/'):lower()==utf8(wide(exe())):gsub('\\','/'):lower()
 ffi.C.CloseHandle(h);return matched
end
function M.status()
 local now=os.time();if M.cache_at==now then return M.cached end;M.cache_at=now
 local h=decode(folder()..'/proxy_health.json')
 local alive=h and h.ready==true and type(h.updated)=='number'and now-h.updated<8 and h.updated<=now+5 and process_matches(h)
 local starting=M.process and ffi.C.WaitForSingleObject(M.process,0)==258
 M.cached={alive=alive==true,starting=starting==true,trusted=M.trusted(),bridge=M.steam_ready(),health=h,updated=h and h.updated or 0}
 if alive then M.cached.message=M.cached.trusted and'代理正在运行（本机 127.0.0.1:'..tostring(h.port)..'）'or'代理已启动；尚未信任本机 CA，请点击下方按钮。'
 elseif starting then M.cached.message=M.stopping and'代理正在停止…'or'代理核心正在启动，请稍候…'
 else M.cached.message='代理未运行；点击“启动代理”。'end
 return M.cached
end
function M.start()
 M.cache_at=nil
 local s=M.status();if s.alive then return true end
 if not require('install').exists(exe())then return nil,'缺少随包 mitmdump.exe，请使用完整构建。'end
 M.stopping=false;require('install').mkdirs(folder())
 F.remove(folder()..'/stop.request');F.remove(folder()..'/proxy_health.json')
 kill_mitmdump_processes(nil)
 ensure_ca_files()
 local args={'--listen-host','127.0.0.1','--listen-port',tostring(M.port),'--mode','regular','--allow-hosts',quote('^api[.]live[.]prod[.]thehelldiversgame[.]com(:443)?$'),
  '--set',quote('confdir='..folder()),'--set',quote('shodan_effect_definitions='..M.home..'/galactic_effect_overrides.json'),
  '--set',quote('shodan_planet_effects='..M.home..'/planet_effects.json'),'--set','flow_detail=0','--set','termlog_verbosity=error','-s',quote(M.root..'/app/network/galactic_effect_proxy.py')}
 local info=ffi.new('shodan_proxy_shell_info');info.size=ffi.sizeof(info);info.mask=0x140
 local verb,file,params,dir=wide('open'),wide(exe()),wide(table.concat(args,' ')),wide(M.root)
 info.verb,info.file,info.parameters,info.directory,info.show=verb,file,params,dir,0
 if shell.ShellExecuteExW(info)==0 then return nil,'无法启动随包代理核心，Windows 错误 '..tonumber(ffi.C.GetLastError())end
 if M.process then ffi.C.CloseHandle(M.process)end;M.process=info.process
 for _=1,35 do
  ffi.C.Sleep(100)
  M.cache_at=nil
  local cur=M.status()
  if cur.alive then
   if not cur.trusted then pcall(M.trust);M.cache_at=nil;M.status()end
   M.revision=M.revision+1;return true
  end
  if M.process and ffi.C.WaitForSingleObject(M.process,0)~=258 then break end
 end
 M.cache_at=nil;M.revision=M.revision+1
 if M.status().alive then return true end
 return nil,'代理核心启动失败（请检查端口 '..tostring(M.port)..' 是否被其他程序占用）。'
end
function M.stop()
 M.stopping=true
 require('install').mkdirs(folder());local ok,why=F.write(folder()..'/stop.request','stop\n')
 if not rawget(_G,'TEST_WORK')then
  ffi.C.Sleep(150)
  kill_mitmdump_processes(nil)
  F.remove(folder()..'/proxy_health.json')
  if M.process then ffi.C.CloseHandle(M.process);M.process=nil end
  M.stopping=false
 end
 M.revision=M.revision+1;M.cache_at=nil;return ok,why
end
function M.refresh_live()
 require('install').mkdirs(folder())
 F.write(folder()..'/refresh.request',tostring(os.time())..'\n')
 M.revision=M.revision+1;M.cache_at=nil
 return true
end
function M.editor_closed(stop_with_editor)
 if not stop_with_editor then return true end
 local s=M.status()
 if not(s.alive or s.starting)then return true end
 return M.stop()
end
function M.launch_option()return require('steam_integration').launch_option()end
function M.steam_ready()return require('steam_integration').ready()end
function M.enabled()
 for _,name in ipairs({'planet_effects.json','galactic_effect_overrides.json'})do
  local p=decode(M.home..'/'..name);if p and p.version==1 and p.enabled==true then return true end
 end
 return false
end
return M
