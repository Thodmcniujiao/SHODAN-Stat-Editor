local ffi=require('ffi')
local I=require('install')
local M={}
local function write(path,data)
 local f,why=io.open(path,'wb');if not f then return nil,why end
 local ok,err=f:write(data);local closed,close_error=f:close()
 if not ok or not closed then return nil,err or close_error end
 if I.read(path)~=data then return nil,'read-back differs' end;return true
end
M.write=write
local function directories(path)
 local out,data={},ffi.new('host_find_data');local handle=ffi.C.FindFirstFileA(path..'/*',data)
 if handle==nil or ffi.cast('intptr_t',handle)==-1 then return out end
 repeat local name=ffi.string(data.name)
  if name~='.'and name~='..'and math.floor(tonumber(data.attributes)/16)%2==1 then out[#out+1]=name end
 until ffi.C.FindNextFileA(handle,data)==0
 ffi.C.FindClose(handle);table.sort(out);return out
end
function M.discover(game)
 local roots={};local found,seen={},{}
 local buffer,size=ffi.new('char[1024]'),ffi.new('uint32_t[1]',1024)
 local hkcu=ffi.cast('void *',ffi.cast('intptr_t',-2147483647))
 if ffi.load('advapi32').RegGetValueA(hkcu,'Software\\Valve\\Steam','SteamPath',2,nil,buffer,size)==0 then roots[#roots+1]=ffi.string(buffer)end
 local library=game and game:gsub('\\','/'):match('^(.-)/steamapps/')
 if library then roots[#roots+1]=library end
 roots[#roots+1]='C:/Program Files (x86)/Steam'
 for _,root in ipairs(roots)do
  for _,account in ipairs(directories(root..'/userdata'))do if account:match('^%d+$')then
   local path=(root..'/userdata/'..account..'/553850/remote/testament_new.sav'):gsub('\\','/')
   if not seen[path:lower()]and I.exists(path)then seen[path:lower()]=true;found[#found+1]=path end
  end end
 end
 table.sort(found);return found
end
function M.new()
 return {read=I.read,write=write,running=I.game_running,remove=os.remove,
  move=function(from,to)if I.move_file(from,to,9)==0 then return nil,'MoveFileEx failed'end;return true end,
  latest_backup=function(path)
   local folder,name=path:match('^(.*)[/\\]([^/\\]+)$');if not folder then return end
   local names=I.list_files(folder,name..'.shodan-backup-*');return #names>0 and folder..'/'..names[#names]or nil
  end}
end
return M
