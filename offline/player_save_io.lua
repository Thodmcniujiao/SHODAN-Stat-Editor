local ffi=require('ffi')
local I=require('install')
local G=require('gamedata')
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
-- Steam account ids survive moving the Steam library to another drive/computer.
-- Manual saves use a path hash so equally named files cannot share backups.
function M.backup_folder(path)
 local normalized=path:gsub('\\','/'):lower()
 local account=normalized:match('/userdata/(%d+)/553850/')
 local key=account and ('steam-'..account)or G.hex64(G.murmur64(ffi.cast('const uint8_t *',normalized),#normalized)):lower()
 return I.home..'/save-backups/'..key
end
function M.new()
 return {read=I.read,write=write,running=I.game_running,remove=os.remove,
  move=function(from,to)if I.move_file(from,to,9)==0 then return nil,'MoveFileEx failed'end;return true end,
  backup_prefix=function(path,kind)
   local folder=M.backup_folder(path);I.mkdirs(folder)
   return folder..'/'..assert(path:match('([^/\\]+)$'),'Save filename unavailable')..'.shodan-'..kind
  end,
  latest_backup=function(path)
   local folder,name=M.backup_folder(path),path:match('([^/\\]+)$');if not name then return end
   local prefix=name..'.shodan-backup-';local best,best_stamp,best_sequence
   for _,entry in ipairs(I.list_files(folder,prefix..'*'))do
    local suffix=entry:sub(#prefix+1)
    local stamp,sequence=suffix:match('^(%d+%-%d+)%-(%d+)$')
    if not stamp then stamp=suffix:match('^(%d+%-%d+)$')end
    sequence=tonumber(sequence)or 0
    if stamp and(not best or stamp>best_stamp or(stamp==best_stamp and sequence>best_sequence))then
     best,best_stamp,best_sequence=entry,stamp,sequence
    end
   end
   return best and folder..'/'..best or nil
  end}
end
return M
