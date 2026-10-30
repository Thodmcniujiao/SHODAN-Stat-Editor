-- File access for the preset folder (Windows, Unicode file names): each preset is its own file named after it,
-- so a preset called 精英 is 精英.json. A path is '<folder>/<file>': the folder as the rest of the editor gives it
-- (the system code page: GetModuleFileNameA), the file name UTF-8 (the preset's name); both are converted to
-- UTF-16 for the wide Windows API. read/write/move/remove/list, as preset_library.lua's folder storage expects.
local ffi=require('ffi')
for _,d in ipairs({
 'int MultiByteToWideChar(unsigned int cp, uint32_t flags, const char *s, int n, uint16_t *w, int wn);',
 'int WideCharToMultiByte(unsigned int cp, uint32_t flags, const uint16_t *w, int wn, char *s, int n, const char *dflt, int *used);',
 'void *CreateFileW(const uint16_t *name, uint32_t access, uint32_t share, void *security, uint32_t disposition, uint32_t flags, void *tmpl);',
 'int ReadFile(void *h, void *buf, uint32_t n, uint32_t *done, void *overlapped);',
 'int WriteFile(void *h, const void *buf, uint32_t n, uint32_t *done, void *overlapped);',
 'int GetFileSizeEx(void *h, int64_t *size);',
 'int CloseHandle(void *handle);',
 'int MoveFileExW(const uint16_t *from, const uint16_t *to, uint32_t flags);',
 'int DeleteFileW(const uint16_t *path);',
 'int CreateDirectoryW(const uint16_t *path, void *security);',
 'uint32_t GetLastError(void);',
 'typedef struct { uint32_t attributes, times[6], size_high, size_low, reserved[2]; uint16_t name[260], short_name[14]; } preset_find_data_w;',
 'void *FindFirstFileW(const uint16_t *pattern, preset_find_data_w *data);',
 'int FindNextFileW(void *find, preset_find_data_w *data);',
 'int FindClose(void *find);',
})do pcall(ffi.cdef,d)end
local K=ffi.C
local M={}
local CP_ACP,CP_UTF8=0,65001
local INVALID=ffi.cast('void *',-1)
local roots={}
local function wide(s,cp)
 local n=K.MultiByteToWideChar(cp,0,s,-1,nil,0)
 if n<=0 then return nil end
 local w=ffi.new('uint16_t[?]',n)
 if K.MultiByteToWideChar(cp,0,s,-1,w,n)<=0 then return nil end
 return w,n-1
end
local function narrow(w,cp)
 local n=K.WideCharToMultiByte(cp,0,w,-1,nil,0,nil,nil)
 if n<=0 then return nil end
 local s=ffi.new('char[?]',n)
 if K.WideCharToMultiByte(cp,0,w,-1,s,n,nil,nil)<=0 then return nil end
 return ffi.string(s)
end
-- '<folder>/<file>' as UTF-16: the folder in the code page, the file name UTF-8
local function path_w(path)
 local folder,file
 for root in pairs(roots)do
  if path:sub(1,#root+1)==root..'/'and(not folder or #root>#folder)then folder,file=root,path:sub(#root+2)end
 end
 if not folder then folder,file=path:match('^(.*)[/\\]([^/\\]*)$')end
 if not folder then return wide(path,CP_UTF8)end
 local a,na=wide(folder,CP_ACP);local b,nb=wide(file,CP_UTF8)
 if not(a and b)then return nil end
 local w=ffi.new('uint16_t[?]',na+1+nb+1)
 ffi.copy(w,a,na*2);w[na]=47;ffi.copy(ffi.cast('uint16_t *',w)+na+1,b,nb*2);w[na+1+nb]=0
 return w
end
M.path_w=path_w
local function bad(h)return h==nil or h==INVALID end
function M.read(path)
 local w=path_w(path);if not w then return nil end
 local h=K.CreateFileW(w,0x80000000,1,nil,3,0x80,nil)   -- GENERIC_READ, share read, OPEN_EXISTING
 if bad(h)then return nil end
 local size=ffi.new('int64_t[1]')
 if K.GetFileSizeEx(h,size)==0 or size[0]>256*1024*1024 then K.CloseHandle(h);return nil end
 local n=tonumber(size[0]);local buf=ffi.new('uint8_t[?]',math.max(n,1));local done=ffi.new('uint32_t[1]')
 local ok=n==0 or K.ReadFile(h,buf,n,done,nil)~=0 and done[0]==n
 K.CloseHandle(h)
 if not ok then return nil end
 return ffi.string(buf,n)
end
function M.write(path,raw)
 local w=path_w(path);if not w then return nil,'Invalid file name: '..path end
 local h=K.CreateFileW(w,0x40000000,0,nil,2,0x80,nil)   -- GENERIC_WRITE, CREATE_ALWAYS
 if bad(h)then return nil,'Could not create '..path end
 local done=ffi.new('uint32_t[1]')
 local ok=#raw==0 or K.WriteFile(h,raw,#raw,done,nil)~=0 and done[0]==#raw
 K.CloseHandle(h)
 if not ok then return nil,'Could not write '..path end
 if M.read(path)~=raw then return nil,'Preset write verification failed: '..path end
 return true
end
function M.move(from,to)
 local a,b=path_w(from),path_w(to)
 if not(a and b)or K.MoveFileExW(a,b,9)==0 then return nil,'Could not replace '..to end   -- REPLACE_EXISTING | WRITE_THROUGH
 return true
end
function M.remove(path)local w=path_w(path);return w and K.DeleteFileW(w)~=0 end
function M.mkdir(path)local w=path_w(path);return w and(K.CreateDirectoryW(w,nil)~=0 or K.GetLastError()==183)end
-- Relative UTF-8 paths, including nested folders. Never follow junctions or scan backups.
function M.list(folder)
 roots[folder]=true
 local out,groups={},{}
 local function scan(relative,depth)
  local data=ffi.new('preset_find_data_w')
  local w=path_w(folder..'/'..relative..'*');if not w then return end
  local find=K.FindFirstFileW(w,data);if bad(find)then return end
  repeat
   local name=narrow(data.name,CP_UTF8)
   if name and name~='.'and name~='..'then
    if data.attributes%32>=16 then
     if depth<16 and data.attributes%2048<1024 and name:lower()~='backup'and name:sub(1,1)~='.'then
      groups[#groups+1]=relative..name;scan(relative..name..'/',depth+1)
     end
    else out[#out+1]=relative..name end
   end
  until K.FindNextFileW(find,data)==0
  K.FindClose(find)
 end
 scan('',0)
 table.sort(out)
 table.sort(groups)
 return out,groups
end
return M
