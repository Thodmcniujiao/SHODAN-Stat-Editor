-- SHODAN Stat Editor Offline: the game's own texts (names, descriptions), for the panel's Name / Description boxes,
-- and the patch that puts typed ones into the game.
-- Strings files (type 0D972BAB10B40FD3; all 265 in archive 9ba626afa44a3aa3 in the game of 2026-10-29: 15 languages,
-- 24840 English texts): u32 magic, u32 version, u32 count, +12 u32 language (English: 0x03F97B57), then count u32 ids,
-- count u32 offsets from the file's start, and the zero-ended UTF-8 texts.
-- A typed text goes into every language's file that holds its id (the game shows it whatever its language), in a patch
-- over that archive (<archive>.patch_N, the editor's own: entity_assets.lua lists it, Restore deletes it); the game's
-- archives are never changed. Read with archives.lua (no Filediver).
local A = require('archives')
local M = { STRINGS = '0D972BAB10B40FD3', ENGLISH = 0x03F97B57 }
local u32 = A.u32

local function texts_of(d)
    local n, out = u32(d, 8), {}
    for i = 0, n - 1 do
        local at = u32(d, 16 + 4 * n + 4 * i)
        out[i + 1] = { u32(d, 16 + 4 * i), d:match('^[^%z]*', at + 1) }
    end
    return out
end
M.texts_of = texts_of

-- data_root: the game's data folder; cache / stamp: archives.index's (where the strings files are, kept per game
-- build). Returns the texts: { english = { id = text }, files = { { key, archive } }, store }
function M.load(data_root, cache, stamp, list_files, store)
    store = store or A.open(data_root)
    local typ = A.raw(M.STRINGS)
    local index = A.index(store, { [typ] = true }, cache, stamp, list_files)
    local out = { english = {}, files = {}, store = store }
    for key, archives in pairs(index) do
        local f = key:sub(9) == typ and store:directory(archives[1]).by[key]
        if f and f.main[2] >= 16 then   -- (a file's header first: only the English ones are read now)
            out.files[#out.files + 1] = { key = key, archive = archives[1] }
            if u32(store:read(archives[1], f.main[1], 16), 12) == M.ENGLISH then
                local d = store:read(archives[1], f.main[1], f.main[2])
                if 16 + 8 * u32(d, 8) <= #d then
                    for _, t in ipairs(texts_of(d)) do out.english[t[1]] = t[2] end
                end
            end
        end
    end
    table.sort(out.files, function(a, b) return a.archive .. a.key < b.archive .. b.key end)
    return out
end

-- a strings file with the texts of `new` (id -> text) in place of its own; nil when it holds none of them
function M.rewrite(d, new)
    local n, hit = u32(d, 8), false
    local texts = {}
    for i = 0, n - 1 do
        local id = u32(d, 16 + 4 * i)
        texts[i + 1] = new[id] or d:match('^[^%z]*', u32(d, 16 + 4 * n + 4 * i) + 1)
        hit = hit or new[id] ~= nil
    end
    if not hit then return nil end
    local offsets, at = {}, 16 + 8 * n
    for i = 1, n do
        local v = at
        offsets[i] = string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216))
        at = at + #texts[i] + 1
    end
    return d:sub(1, 16 + 4 * n) .. table.concat(offsets) .. table.concat(texts, '\0') .. '\0'
end

-- Adds the strings files holding a typed text (renames: id -> text) to the install's patches (writes: name ->
-- bytes, as preload_io / unit_aliases make them). A patch for that archive already being written gets them added;
-- else the editor's own patch of it (owned) or the next free patch number. UA: unit_aliases (archive / read_archive).
-- Returns how many strings files.
function M.add_to(writes, texts, renames, owned, data_root, UA, exists)
    if not (texts and renames and next(renames)) then return 0 end
    local by_archive, count = {}, 0
    for _, f in ipairs(texts.files) do
        local r = texts.store:resource(f.archive, f.key)
        local d = r and r.main
        local bytes = d and #d >= 16 and 16 + 8 * u32(d, 8) <= #d and M.rewrite(d, renames)
        if bytes then
            by_archive[f.archive] = by_archive[f.archive] or {}
            table.insert(by_archive[f.archive], { name = f.key:sub(1, 8), type = f.key:sub(9), main = bytes })
            count = count + 1
        end
    end
    for archive, list in pairs(by_archive) do M.merge(writes, archive, list, owned, data_root, UA, exists) end
    return count
end

-- Puts resources (list: { name = raw, type = raw, main, gpu, stream }) into the patch over `archive` among the
-- install's writes: a patch for it already being written gets them added (theirs replaced by name and type); else the
-- editor's own patch of it (owned) or the next free patch number. Read back before it is kept. (physics.lua too)
function M.merge(writes, archive, list, owned, data_root, UA, exists)
    local name = nil
    for w in pairs(writes) do if w:match('^' .. archive .. '%.patch_%d+$') then name = w end end
    if not name then for o in pairs(owned or {}) do if o:match('^' .. archive .. '%.patch_%d+$') then name = o end end end
    if not name then
        local n = 0
        while exists(data_root .. '/' .. archive .. '.patch_' .. n) or exists(data_root .. '/' .. archive .. '.patch_' .. n .. '.gpu_resources')
              or exists(data_root .. '/' .. archive .. '.patch_' .. n .. '.stream') do n = n + 1 end
        name = archive .. '.patch_' .. n
    end
    -- what the patch already holds (preload's packages, the strings), then these over it
    local resources, at = {}, {}
    if writes[name] then
        for key, r in pairs(UA.read_archive(writes[name], writes[name .. '.gpu_resources'], writes[name .. '.stream'])) do
            resources[#resources + 1] = { name = r.name, type = r.type, main = r.main, gpu = r.gpu, stream = r.stream }
            at[key] = #resources
        end
    end
    for _, r in ipairs(list) do
        local k = at[r.name .. r.type]
        local item = { name = r.name, type = r.type, main = r.main, gpu = r.gpu, stream = r.stream }
        if k then resources[k] = item else resources[#resources + 1] = item; at[r.name .. r.type] = #resources end
    end
    local a = UA.archive(resources)
    local back = UA.read_archive(a.main, a.gpu, a.stream)
    for _, r in ipairs(resources) do
        local b = assert(back[r.name .. r.type], 'patch read-back: a file is missing')
        assert(b.main == r.main, 'patch read-back differs')
    end
    writes[name] = a.main
    writes[name .. '.gpu_resources'] = #a.gpu > 0 and a.gpu or nil
    writes[name .. '.stream'] = #a.stream > 0 and a.stream or nil
    return name
end

return M
