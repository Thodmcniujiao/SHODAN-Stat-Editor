-- Ownership and rollback for new triad patches. Only validated basenames under the
-- game's data folder are touched; pre-existing mod files are never adopted.
local ffi=require('ffi')
local G=require('gamedata')
local I=require('install')
local M={}
local function hash(s)return G.hex64(G.murmur64(ffi.cast('const uint8_t *',s),#s))end
local function valid(name)
 local root,suffix=name:match('^(%x+%.patch_%d+)(.*)$')
 return root and #root:match('^(%x+)')==16 and(suffix==''or suffix=='.gpu_resources'or suffix=='.stream')
end
local function marker(home)return home..'/entity_assets_installed.txt'end
local function load(home)
 local out={}
 for line in (I.read(marker(home))or''):gmatch('[^\r\n]+')do
  local name,h=line:match('^(%S+)%s+(%x+)$')
  if name and valid(name)and #h==16 then out[name]=out[name]or{};out[name][h]=true end
 end
 return out
end
local function save(home,list)
 I.mkdirs(home);local lines={}
 for name,hashes in pairs(list)do for h in pairs(hashes)do lines[#lines+1]=name..' '..h end end
 table.sort(lines)
 local data=table.concat(lines,'\n')..(#lines>0 and'\n'or'')
 local path=marker(home);local tmp=path..'.new'
 local f=io.open(tmp,'wb');if not f then return nil,'could not stage asset ownership'end
 local ok=f:write(data);f:close()
 if not ok or I.read(tmp)~=data or ffi.C.MoveFileExA(tmp,path,9)==0 then return nil,'could not save asset ownership'end
 return true
end
local function atomic(path,s)
 local tmp=path..'.shodan-entity-new'
 local f=io.open(tmp,'wb');if not f then return nil,'could not stage '..path end
 local ok=f:write(s);f:close()
 if not ok or I.read(tmp)~=s then os.remove(tmp);return nil,'asset read-back failed'end
 if ffi.C.MoveFileExA(tmp,path,9)==0 then os.remove(tmp);return nil,'could not replace '..path end
 return true
end
function M.owned(home)
 local out={};for name in pairs(load(home or I.home))do out[name]=true end;return out
end
function M.begin(game,desired,options)
 options=options or{};local home=options.home or I.home
 assert(not I.game_running(),'Helldivers 2 is running: close it first.')
 local parent=game:gsub('\\','/'):match('^(.*)/[Gg][Aa][Mm][Ee]/?$')
 assert(parent and parent~='','expected the game data/game folder')
 local old=load(home);local all={};for n in pairs(old)do all[n]=true end
 for n,s in pairs(desired)do assert(valid(n)and type(s)=='string','invalid entity asset output');all[n]=true end
 local entries,pending,final={}, {},{}
 for name in pairs(all)do
  assert(valid(name),'unsafe asset basename')
  local current=I.read(parent..'/'..name)
  if current and not(old[name]and old[name][hash(current)])then
   error('Another tool owns or changed '..name..'; no files were installed.')
  end
  local wanted=desired[name]
  entries[#entries+1]={name=name,path=parent..'/'..name,before=current,after=wanted}
  if current then pending[name]=pending[name]or{};pending[name][hash(current)]=true end
  if wanted then pending[name]=pending[name]or{};pending[name][hash(wanted)]=true;final[name]={[hash(wanted)]=true}end
 end
 table.sort(entries,function(a,b)return a.name<b.name end)
 local self={entries=entries,old=old,pending=pending,final=final,home=home,activated=false}
 function self:rollback()
  local failures={}
  for i=#self.entries,1,-1 do
   local e=self.entries[i];local current=I.read(e.path)
   if current~=e.before then
    if current~=e.after then failures[#failures+1]=e.name..' changed outside the transaction'
    elseif e.before then local ok=atomic(e.path,e.before);if not ok then failures[#failures+1]=e.name end
    elseif current and ffi.C.DeleteFileA(e.path)==0 then failures[#failures+1]=e.name end
   end
  end
  if #failures==0 then local ok,why=save(self.home,self.old);if not ok then failures[#failures+1]=why end end
  if #failures>0 then return nil,table.concat(failures,', ')end
  self.activated=false;return true
 end
 function self:activate()
  local ok,why=save(self.home,self.pending);if not ok then return nil,why end
  for _,e in ipairs(self.entries)do
   if e.before~=e.after then
    if e.after then ok,why=atomic(e.path,e.after)
    elseif e.before then ok=ffi.C.DeleteFileA(e.path)~=0;why='could not remove old entity patch'end
    if not ok then self:rollback();return nil,why..': '..e.name end
   end
  end
  self.activated=true;return true
 end
 function self:commit()
  assert(self.activated,'asset transaction is not active')
  return save(self.home,self.final)
 end
 return self
end
return M
