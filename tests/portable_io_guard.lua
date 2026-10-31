-- Fail a real offline-host smoke test on any AppData access or nonportable write.
local F=require('preset_files')
local original_getenv,original_open=os.getenv,io.open
local function normalized(p)return tostring(p):gsub('\\','/'):lower():gsub('/+$','')end
local work=normalized(assert(TEST_WORK))
local function check(path,writing)
 local p=normalized(path)
 assert(not p:find('/appdata/',1,true),'offline host accessed AppData: '..tostring(path))
 if writing then assert(p:sub(1,#work+1)==work..'/','offline host wrote outside its portable test folder: '..tostring(path))end
end
os.getenv=function(name)
 assert(name~='LOCALAPPDATA' and name~='APPDATA','offline host requested '..name)
 return original_getenv(name)
end
io.open=function(path,mode,...)
 check(path,mode and mode:find('[wa+]')~=nil)
 return original_open(path,mode,...)
end
for name,writing in pairs({read=false,write=true,remove=true,mkdir=true,list=false})do
 local fn=F[name]
 if fn then F[name]=function(path,...)check(path,writing);return fn(path,...)end end
end
local move=F.move
if move then F.move=function(a,b,...)check(a,true);check(b,true);return move(a,b,...)end end
return true
