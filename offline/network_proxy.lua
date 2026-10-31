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
local function certificate()
 local pem=F.read(folder()..'/mitmproxy-ca-cert.pem');if not pem then return end
 local size=ffi.new('uint32_t[1]')
 if crypt.CryptStringToBinaryA(pem,#pem,0,nil,size,nil,nil)==0 then return end
 local bytes=ffi.new('uint8_t[?]',size[0])
 if crypt.CryptStringToBinaryA(pem,#pem,0,bytes,size,nil,nil)==0 then return end
 return bytes,tonumber(size[0])
end
local function root_store()
 return crypt.CertOpenStore(ffi.cast('const void *',10),0,nil,0x14000,wide('ROOT')) -- system W, current user, existing
end
function M.trusted()
 local bytes,size=certificate();if not bytes then return false end
 local store=root_store();if store==nil then return false end
 local found=false;local context=nil
 while true do
  context=crypt.CertEnumCertificatesInStore(store,context);if context==nil then break end
  if context.size==size and ffi.string(context.bytes,size)==ffi.string(bytes,size)then found=true;crypt.CertFreeCertificateContext(context);break end
 end
 crypt.CertCloseStore(store,0);return found
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
 local s=M.status();if s.alive or s.starting then return true end
 if not require('install').exists(exe())then return nil,'缺少随包 mitmdump.exe，请使用完整构建。'end
 M.stopping=false;require('install').mkdirs(folder());F.remove(folder()..'/stop.request')
 local args={'--listen-host','127.0.0.1','--listen-port',tostring(M.port),'--mode','regular','--allow-hosts',quote('^api[.]live[.]prod[.]thehelldiversgame[.]com(:443)?$'),
  '--set',quote('confdir='..folder()),'--set',quote('shodan_effect_definitions='..M.home..'/galactic_effect_overrides.json'),
  '--set',quote('shodan_planet_effects='..M.home..'/planet_effects.json'),'--set','flow_detail=0','--set','termlog_verbosity=error','-s',quote(M.root..'/app/network/galactic_effect_proxy.py')}
 local info=ffi.new('shodan_proxy_shell_info');info.size=ffi.sizeof(info);info.mask=0x140
 local verb,file,params,dir=wide('open'),wide(exe()),wide(table.concat(args,' ')),wide(M.root)
 info.verb,info.file,info.parameters,info.directory,info.show=verb,file,params,dir,0
 if shell.ShellExecuteExW(info)==0 then return nil,'无法启动随包代理核心，Windows 错误 '..tonumber(ffi.C.GetLastError())end
 if M.process then ffi.C.CloseHandle(M.process)end;M.process=info.process
 M.revision=M.revision+1;M.cache_at=nil;return true
end
function M.stop()
 M.stopping=true
 require('install').mkdirs(folder());local ok,why=F.write(folder()..'/stop.request','stop\n')
 M.revision=M.revision+1;M.cache_at=nil;return ok,why
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
