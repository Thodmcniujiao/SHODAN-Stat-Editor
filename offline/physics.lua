-- SHODAN Stat Editor Offline: vehicle handling, the exosuits' movement and the enemies' animation speed (after upstream
-- 4.5.1's offline/vehicles.lua, without its fixed archive list). The files are found by the archive index
-- (archives.lua: any archive holding them, kept per game build), read into one buffer the panel edits like a table
-- (SHODAN_PHYSICS: base address, files['<name hex>.<type hex>'] = { at, size }), and Install puts the changed ones into
-- the editor's patch over the base archive (game_texts.merge: with the names and descriptions, the editor's own patch,
-- Restore deletes it); the game's archives are never changed.
--   physics files (5F7203C8F280DAB8): named as the vehicle's entity (the FRVs, the tanks, ...)
--   state machines (A486D4045106165C): the exosuits' (79E4B3D2DA5E45E3) and the enemies' (enemy_anim.lua)
-- The panel asks for the files it shows (load: once, the first time a vehicle or enemy page is built), so only those
-- are read (a few MB; the game has ~4800 physics files, 145 MB).
local ffi = require('ffi')
local A = require('archives')
local M = { PHYSICS = '5F7203C8F280DAB8', STATE_MACHINE = 'A486D4045106165C', BASE = '9ba626afa44a3aa3' }

-- the index of both types (cache: its file; stamp: the game build's)
function M.index(store, cache, stamp, list_files)
    return A.index(store, { [A.raw(M.PHYSICS)] = true, [A.raw(M.STATE_MACHINE)] = true }, cache, stamp, list_files)
end

-- store: archives.open's; index: M.index's. Returns the panel's SHODAN_PHYSICS (its base and files once loaded).
function M.setup(store, index, log)
    log = log or function() end
    M.store, M.idx, M.files, M.original, M.from = store, index, {}, {}, {}
    M.shared = { files = M.files }
    -- names: { '<name hex>.<type hex>' }; the ones the game has are read (the first archive the index lists), once
    function M.shared.load(names)
        if M.buffer then return M.shared.base end
        local found, total, seen = {}, 0, {}
        for _, id in ipairs(names or {}) do
            local name, typ = id:match('^(%x+)%.(%x+)$')
            if name and #name == 16 and #typ == 16 and not seen[id:upper()] then
                seen[id:upper()] = true
                local key = A.raw(name) .. A.raw(typ)
                local list = M.idx[key]
                if list then
                    local ok, r = pcall(M.store.resource, M.store, list[1], key)
                    if ok and r and r.main and #r.main > 0 then
                        found[#found + 1] = { id = name:upper() .. '.' .. typ:upper(), key = key, r = r }
                        total = total + #r.main + 16
                    elseif not ok then log('physics: ' .. id .. ': ' .. tostring(r)) end
                end
            end
        end
        table.sort(found, function(a, b) return a.id < b.id end)
        M.buffer = ffi.new('uint8_t[?]', math.max(total, 16))
        local at = 0
        for _, f in ipairs(found) do
            ffi.copy(M.buffer + at, f.r.main, #f.r.main)
            M.files[f.id] = { at = at, size = #f.r.main }
            M.original[f.id], M.from[f.id] = f.r, f.key
            at = at + #f.r.main + (16 - #f.r.main % 16) % 16
        end
        M.shared.base = tonumber(ffi.cast('uintptr_t', M.buffer))
        log(string.format('vehicle handling and animation: %d of %d files (%.1f MB)', #found, #names, total / 1048576))
        return M.shared.base
    end
    return M.shared
end

-- the files the panel changed: { { name = raw, type = raw, main, gpu, stream } }
function M.reset()
    for id,f in pairs(M.files or{})do
        local original=M.original[id]
        if M.buffer and original then ffi.copy(M.buffer+f.at,original.main,f.size)end
    end
end
function M.changed()
    local out = {}
    for id, f in pairs(M.files or {}) do
        local bytes = ffi.string(M.buffer + f.at, f.size)
        local o = M.original[id]
        if bytes ~= o.main then
            out[#out + 1] = { id = id, name = M.from[id]:sub(1, 8), type = M.from[id]:sub(9), main = bytes,
                              gpu = o.gpu ~= '' and o.gpu or nil, stream = o.stream ~= '' and o.stream or nil }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- Adds the changed files to the install's patches (writes: name -> bytes), over the base archive (the patch the game
-- always loads; mod managers' too), merged with what that patch already gets. Returns the ids written.
function M.add_to(writes, owned, data_root, UA, exists, merge)
    local list = M.changed()
    if #list == 0 then return list end
    local base = M.store:has(M.BASE) and M.BASE
    assert(base, 'the base archive ' .. M.BASE .. ' is not in the game files')
    merge(writes, base, list, owned, data_root, UA, exists)
    return list
end

return M
