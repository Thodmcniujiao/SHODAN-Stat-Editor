-- External display ("planning") names for enum/record row ids: 轨道飞鹰 / 游戏数据 left lists.
-- Legacy import files, read in this order (later wins), then split into TypeIdNames/<type>.json:
--   %LOCALAPPDATA%\SHODAN\StatEditor\record_names.json
--   %LOCALAPPDATA%\SHODAN\StatEditor\record_names.txt
-- JSON, nested:        {"version":1,"types":{"projectile":{"282":"设计名"}}}
-- JSON, flat:          {"projectile:282":"设计名"}
-- JSON, records array: {"records":[{"type":"projectile","id":282,"name":"设计名"}]}
-- TXT (tab or spaces; the name is the rest of the line; # starts a comment):
--   projectile 282 轨道炮射弹
--   projectile	282	轨道炮射弹
-- Type aliases: projectile/proj, explosion/expl, damage/dmg, status/status_effect,
-- beam/laser, stratagem/stratagem_type, orbital/orbital_ability.
local J = require('json_data')
local F = require('preset_files')
local IDs = require('name_ids')
local M = { loaded = false, by = {}, count = 0, errors = {}, dir = nil }
local ALIASES = {
    projectile = 'projectile', proj = 'projectile', projectile_type = 'projectile',
    explosion = 'explosion', expl = 'explosion', explosion_type = 'explosion',
    damage = 'damage', damage_type = 'damage', dmg = 'damage',
    status = 'status', status_effect = 'status', status_effect_type = 'status',
    arc = 'arc', arc_type = 'arc',
    beam = 'beam', laser = 'beam', beam_type = 'beam',
    stratagem = 'stratagem', stratagem_type = 'stratagem', strat = 'stratagem',
    orbital = 'orbital', orbital_ability = 'orbital', orbital_weapon = 'orbital',
    bombardment = 'bombardment', bombard = 'bombardment', orbital_bombardment = 'bombardment',
    eagle = 'eagle', eagle_type = 'eagle',
}
local function trim(s) return (tostring(s):gsub('^%s+', ''):gsub('%s+$', '')) end
local function type_key(t)
    local s = trim(t):lower():gsub('[%s%-]+', '_')
    return ALIASES[s] or s
end
local function id_key(id)
    local s = trim(id)
    local hex = s:match('^0[xX](%x+)$')
    if hex then
        -- enum ids are 32-bit; a 64-bit orbital entity hash has to stay a hex string
        if #hex <= 8 then s = tostring(tonumber(hex, 16)) else s = hex:upper() end
    end
    if s:match('^%d+$') then s = s:gsub('^0+(%d)', '%1') end
    if s:match('^%x+$') and #s == 16 then s = s:upper() end
    return s
end
local function put(t, id, name)
    local key, value = type_key(t), trim(name)
    if key == '' or value == '' then return end
    local idk = id_key(id)
    if idk == '' then return end
    local list = M.by[key] or {}
    M.by[key] = list
    if list[idk] == nil then M.count = M.count + 1 end
    list[idk] = value
end
local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('*a')
    f:close()
    return s
end
function M.read_legacy(dir)
    M.loaded, M.by, M.count, M.errors, M.dir = true, {}, 0, {}, dir
    local json = dir and read(dir .. '/record_names.json')
    if json and json ~= '' then
        local ok, data = pcall(J.decode, json)
        if not ok or type(data) ~= 'table' then
            M.errors[#M.errors + 1] = 'record_names.json: ' .. tostring(data)
        else
            local types = type(data.types) == 'table' and data.types or data
            for t, list in pairs(types) do
                if type(list) == 'table' and type(t) == 'string' then
                    for id, name in pairs(list) do
                        if type(name) == 'string' then put(t, id, name) end
                    end
                elseif type(list) == 'string' and type(t) == 'string' and t:find(':', 1, true) then
                    local tt, id = t:match('^(.-):(.+)$')
                    if tt then put(tt, id, list) end
                end
            end
            if type(data.records) == 'table' then
                for _, r in ipairs(data.records) do
                    if type(r) == 'table' and r.type and r.id and r.name then put(r.type, r.id, r.name) end
                end
            end
        end
    end
    local txt = dir and read(dir .. '/record_names.txt')
    if txt and txt ~= '' then
        local line_no = 0
        for line in (txt .. '\n'):gmatch('(.-)\r?\n') do
            line_no = line_no + 1
            line = trim(line)
            if line ~= '' and line:sub(1, 1) ~= '#' then
                local t, id, name
                if line:find('\t', 1, true) then
                    t, id, name = line:match('^(.-)\t(.-)\t(.*)$')
                else
                    t, id, name = line:match('^(%S+)%s+(%S+)%s+(.+)$')
                end
                if t and id and name and trim(name) ~= '' then put(t, id, name)
                else M.errors[#M.errors + 1] = 'record_names.txt line ' .. line_no .. ': expected "type id name"' end
            end
        end
    end
    return M.count, M.errors
end
local TYPES={'damage','projectile','explosion','arc','beam','status','stratagem','bombardment','eagle'}
local function index_less(a,b)
 local ia,ib=IDs.index(a),IDs.index(b)
 if ia and ib then
  if ia~=ib then return tonumber(ia)<tonumber(ib)end
 elseif ia or ib then return ia~=nil end
 return a<b
end
local function write(path,raw)
 assert(F.write(path..'.new',raw));assert(F.move(path..'.new',path))
end
local function save(t,names)
 assert(t:match('^[%w_-]+$'),'invalid TypeID name')
 local path=M.paths and M.paths[t]or(M.folder..'/'..t..'.json')
 write(path,J.encode({version=1,type=t,names=names},true,index_less))
end
function M.load(dir)
 local previous,previous_count,previous_paths=M.by,M.count,M.paths
 -- Import old JSON/TXT once. Keep the originals intact, and keep hash names separate from local indices.
 M.read_legacy(dir);M.hash_names={};local legacy=M.by
 local ordered={};for t in pairs(legacy)do ordered[#ordered+1]=t end;table.sort(ordered)
 for _,t in ipairs(ordered)do for id,name in pairs(legacy[t])do
  if not IDs.index(id)then local h=IDs.hex(id);if h and not M.hash_names[h]then M.hash_names[h]=name end end
 end end
 M.folder=assert(dir)..'/TypeIdNames';assert(F.mkdir(M.folder),'Cannot create '..M.folder)
 local paths={};for _,p in ipairs(F.list(M.folder))do if p:lower():match('%.json$')then paths[#paths+1]=p end end
 if #paths==0 and #M.errors>0 then return M.count,M.errors end
 if #paths==0 then
  M.paths={}
  for _,t in ipairs(TYPES)do
   local names={};for id,name in pairs(legacy[t]or{})do local index=IDs.index(id);if index then names[index]=name end end
   save(t,names)
  end
  for t,list in pairs(legacy)do
   if t~='orbital'and not F.read(M.folder..'/'..t..'.json')then
    local names={};for id,name in pairs(list)do local index=IDs.index(id);if index then names[index]=name end end
    if next(names)then save(t,names)end
   end
  end
 end
 local by,count,errors,seen,by_path,rewrites={},0,{},{},{},{}
 for _,path in ipairs(F.list(M.folder))do if path:lower():match('%.json$')then
  local ok,why=pcall(function()
   local raw=assert(F.read(M.folder..'/'..path));local data=J.decode(raw)
   assert(type(data)=='table'and data~=J.null,'expected object')
   local t=type_key(data.type or path:gsub('%.json$',''))
   assert(t:match('^[%w_-]+$')and not seen[t],'duplicate/invalid TypeID '..t);seen[t]=true
   local names=data.names or data.records or data;assert(type(names)=='table'and names~=J.null,'names must be an object')
   local list={}
   for id,name in pairs(names)do
    if names~=data or(id~='type'and id~='version')then
     if type(name)=='table'then id,name=name.index or name.id,name.name end
     local index=assert(IDs.index(id),'invalid local index '..tostring(id))
     assert(type(name)=='string'and #name<=1024 and not name:find('[%z\1-\31]'),'invalid planning name')
     assert(not list[index],'duplicate index '..index);list[index]=name;count=count+1
    end
   end
   by[t]=list
   by_path[t]=M.folder..'/'..path
   if #names>0 and type(names[1])=='table'then
    table.sort(names,function(a,b)return index_less(a.index or a.id,b.index or b.id)end)
   end
   local ordered=J.encode(data,true,index_less)
   if raw~=ordered then rewrites[#rewrites+1]={path=by_path[t],raw=ordered}end
  end)
  if not ok then errors[#errors+1]=path..': '..tostring(why)end
 end end
 -- Reorder existing files only after every file validates; preserve their names and metadata.
 if #errors==0 then for _,file in ipairs(rewrites)do
  local ok,why=pcall(write,file.path,file.raw)
  if not ok then errors[#errors+1]=file.path..': '..tostring(why)end
 end end
 if #errors==0 then M.by,M.count,M.paths=by,count,by_path else M.by,M.count,M.paths=previous,previous_count,previous_paths end
 M.errors=errors;M.loaded=true
 return M.count,errors
end
function M.seed(t,entries)
 t=type_key(t);if not M.loaded or not M.folder or #M.errors>0 then return end
 local names=M.by[t]or{};local changed=M.by[t]==nil
 for id,name in pairs(entries)do
  local index=assert(IDs.index(id));if names[index]==nil then names[index]=name;changed=true end
 end
 if changed then save(t,names);M.by[t]=names end
 M.count=0;for _,list in pairs(M.by)do for _ in pairs(list)do M.count=M.count+1 end end
end
function M.reload(dir)
 local old,oldcount=M.by,M.count
 local count,errors=M.load(dir or M.dir)
 if #errors>0 then M.by,M.count=old,oldcount;return oldcount,errors end
 return count,errors
end
function M.name(t, id)
    if not M.loaded then return nil end
    local list = M.by[type_key(t)]
    return list and list[id_key(id)] or nil
end
return M
