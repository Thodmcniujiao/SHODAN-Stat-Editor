-- External display ("planning") names for enum/record row ids: 轨道飞鹰 / 游戏数据 left lists.
-- Files, read in this order (later wins):
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
function M.load(dir)
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
function M.reload(dir) return M.load(dir or M.dir) end
function M.name(t, id)
    if not M.loaded then return nil end
    local list = M.by[type_key(t)]
    return list and list[id_key(id)] or nil
end
return M
