-- SHODAN Stat Editor Offline: the game's data files as the game holds them in memory.
-- Every data file is decrypted into its own allocation (high in the address space, like the game's), so Stat
-- Editor's table scan finds the tables as it does in game. The game turns a table's stored offsets into
-- addresses when it loads it; the host does the same for the fields Stat Editor follows, and links each
-- destruction level to its demolition tier (stored unlinked). Those fields always go back as they were stored.
-- Install: per file, the bytes Stat Editor changed go into the original plain text, the hash is corrected, the
-- file is sealed, read back and checked.
local ffi = require('ffi')
local bit = require('bit')
local G = require('gamedata')

-- (VirtualAlloc, VirtualFree and memcmp are declared by gamedata.lua)
local MEM_COMMIT_RESERVE_TOP, PAGE_READWRITE, MEM_RELEASE = 0x103000, 0x04, 0x8000

local M = { files = {}, log = print }
local u64p = ffi.typeof('uint64_t *')
local NONE = 0xFFFFFFFFFFFFFFFFULL

local function u32(p, o) return ffi.cast('uint32_t *', p + o)[0] end
local function addr(p) return ffi.cast('uint64_t', ffi.cast('uintptr_t', p)) end

-- ---------------------------------------------------------------- the fields the game resolves at load
-- per table type: function(payload pointer, size, rel) calling rel(offset) for each stored offset Stat Editor
-- follows (payload-relative u64; 0 and -1 are none)
local RELOC = {
    [0x683E604F] = function(P, size, rel) for k = 0, 4 do rel(k * 16) end end,                -- attachment deltas
    [0x63CE0FEB] = function(P, size, rel)                                                     -- armor passive
        if u32(P, 24) > 0 then rel(16) end
        if u32(P, 40) > 0 then rel(32) end
    end,
    [0x49795156] = function(P, size, rel) rel(0) end,                                         -- destruction map
    [0xFB45E243] = function(P, size, rel) rel(0) end,                                         -- demolition tiers
    [0xD6A11545] = function(P, size, rel) rel(0) end,                                         -- destruction settings
    [0x1E604234] = function(P, size, rel)                                                     -- attachment items
        rel(0)
        for r = 0, u32(P, 8) - 1 do rel(16 + r * 88); rel(16 + r * 88 + 48) end
    end,
    [0x30EB6399] = function(P, size, rel)                                                     -- stratagems
        rel(0)
        for r = 0, u32(P, 8) - 1 do rel(16 + r * 400 + 16); rel(16 + r * 400 + 64); rel(16 + r * 400 + 152) end
    end,
}

-- ---------------------------------------------------------------- loading
local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close()
    return s
end

-- `cipher`: the original sealed file. The plain text goes into a top-down allocation.
local function place(name, cipher)
    local n = #cipher - G.SEALBYTES
    local p = ffi.cast('uint8_t *', ffi.C.VirtualAlloc(nil, math.max(n, 1), MEM_COMMIT_RESERVE_TOP, PAGE_READWRITE))
    assert(p ~= nil, 'out of memory for ' .. name)
    local tmp, m = G.open_sealed(cipher)
    if not tmp then ffi.C.VirtualFree(p, 0, MEM_RELEASE); return nil, m end
    ffi.copy(p, tmp, n)
    G.free(tmp)
    return p, n
end

-- a file's plain text to build on: another mod's version loses only its hash correction (the game checks the
-- hash, so a mod's file carries one too), this editor's own goes in its place
local function open_base(cipher)
    local p, n = G.open_sealed(cipher)
    if p then G.clear_correction(p, n) end
    return p, n
end

M.modded = {}   -- name -> true: a file another mod changed (built on, its changes kept)

-- folder: data/game; originals: name -> sealed original (from the backups, else the game folder)
function M.load(folder, originals)
    local dll = assert(read(folder .. '/game.dll'), 'game.dll not found in ' .. folder)
    local problems = {}
    for name, cipher in pairs(originals) do
        local p, n = place(name, cipher)
        if not p then
            problems[#problems + 1] = name .. ': ' .. tostring(n)
        else
            local hash = G.murmur64(p, n)
            if not G.game_dll_has(dll, hash) then
                problems[#problems + 1] = name .. ': not the version this game expects'
                ffi.C.VirtualFree(p, 0, MEM_RELEASE)
            else
                if G.clear_correction(p, n) then M.modded[name] = true end
                M.files[name] = { name = name, p = p, n = n, hash = hash, cipher = cipher, fields = {} }
            end
        end
    end
    M.relocate()
    return problems
end

function M.relocate()
    local tiers = {}   -- demolition tier type -> its template's address
    for _, f in pairs(M.files) do
        for _, h in ipairs(G.headers(f.p, f.n)) do
            local P, size = f.p + h.at + 24, h.size
            local fn = RELOC[h.type]
            if fn then
                fn(P, size, function(o)
                    if o + 8 > size then return end
                    local v = ffi.cast(u64p, P + o)[0]
                    if v ~= 0 and v ~= NONE and v < size then
                        ffi.cast(u64p, P + o)[0] = addr(P) + v
                        f.fields[#f.fields + 1] = h.at + 24 + o
                    end
                end)
            end
            if h.type == 0xFB45E243 and u32(P, 8) > 0 then
                for k = 0, u32(P, 8) - 1 do tiers[u32(P, 16 + k * 16)] = addr(P) + 16 + k * 16 end
            end
        end
    end
    for _, f in pairs(M.files) do
        for _, h in ipairs(G.headers(f.p, f.n)) do
            if h.type == 0xD6A11545 and h.size >= 144 then
                local P = f.p + h.at + 24
                for level = 0, 2 do
                    for _, o in ipairs({ 16, 32 }) do
                        local at = level * 48 + o
                        local t = tiers[u32(P, at + 8)]
                        if t and ffi.cast(u64p, P + at)[0] == NONE then
                            ffi.cast(u64p, P + at)[0] = t
                            f.fields[#f.fields + 1] = h.at + 24 + at
                        end
                    end
                end
            end
        end
    end
    for _, f in pairs(M.files) do
        f.resolved = {}
        for _, o in ipairs(f.fields) do for k = 0, 7 do f.resolved[o + k] = true end end
    end
end

-- ---------------------------------------------------------------- what changed
-- the plain text to install for a file (a new buffer) and the offsets of changed f32-looking words, or nil when
-- nothing changed. Resolved fields keep their stored bytes.
local function changes(f)
    local orig, n = open_base(f.cipher)
    local changed, words = 0, {}
    local a, b = ffi.cast('uint64_t *', f.p), ffi.cast('uint64_t *', orig)
    for w = 0, math.floor(n / 8) - 1 do
        if a[w] ~= b[w] then
            for k = w * 8, w * 8 + 7 do
                if f.p[k] ~= orig[k] and not f.resolved[k] then
                    orig[k] = f.p[k]
                    changed = changed + 1
                    words[k - k % 4] = true
                end
            end
        end
    end
    for k = n - n % 8, n - 1 do
        if f.p[k] ~= orig[k] and not f.resolved[k] then orig[k] = f.p[k]; changed = changed + 1; words[k - k % 4] = true end
    end
    if changed == 0 then G.free(orig); return nil end
    -- floats among the changed words (a salt for one-table files): a value with decimals between 1e-4 and 1e7
    local floats = {}
    -- A uint64 hash can have a low/high half that happens to look like f32. Never use those bits
    -- as a variable hash-correction salt. Known resource-bearing records only offer actual float members.
    local stratagem_floats
    if f.name=='generated_stratagem_settings.dl_bin'then
        stratagem_floats={}
        for _,h in ipairs(G.headers(f.p,f.n))do if h.type==0x30EB6399 then
            local P=h.at+24;local count=u32(f.p,P+8)
            if 16+count*400<=h.size then for i=0,count-1 do
                for _,off in ipairs({84,88,92,96,100,104,108})do stratagem_floats[P+16+i*400+off]=true end
            end end
        end end
    elseif f.name=='generated_projectile_settings.dl_bin'or f.name=='generated_explosion_settings.dl_bin'or f.name=='generated_arc_settings.dl_bin'or f.name=='generated_beam_settings.dl_bin'or f.name=='generated_status_effect_settings.dl_bin'then
        stratagem_floats={}
        local C=require(f.name=='generated_projectile_settings.dl_bin'and'projectile_components'or f.name=='generated_arc_settings.dl_bin'and'arc_components'or f.name=='generated_beam_settings.dl_bin'and'beam_components'or f.name=='generated_status_effect_settings.dl_bin'and'status_components'or'explosion_components')
        for _,h in ipairs(G.headers(f.p,f.n))do if h.type==C.TYPE then
            local P=h.at+24;local count=u32(f.p,P+8)
            if 16+count*C.SIZE<=h.size then for i=0,count-1 do
                for _,off in ipairs(C.FLOAT_OFFSETS)do stratagem_floats[P+16+i*C.SIZE+off]=true end
                for _,array in ipairs(C.ARRAYS or{})do
                    local R=P+16+i*C.SIZE+array.offset
                    local count=u32(f.p,R+8);local pad=u32(f.p,R+12)
                    local target=tonumber(ffi.cast('uint64_t *',f.p+R)[0])
                    if target>=h.size then target=target-tonumber(ffi.cast('uintptr_t',f.p+P))end
                    if count<=4096 and pad==0 and target>=16+u32(f.p,P+8)*C.SIZE and target+count*array.stride<=h.size then
                        for item=0,count-1 do for _,off in ipairs(array.value_offsets)do stratagem_floats[P+target+item*array.stride+off]=true end end
                    end
                end
            end end
        end end
    end
    for o in pairs(words) do
        local v = ffi.cast('float *', orig + o)[0]
        local i = u32(orig, o)
        if (not stratagem_floats or stratagem_floats[o])and v == v and math.abs(v) >= 1e-4 and math.abs(v) < 1e7 and i >= 0x38D1B717 then floats[#floats + 1] = o end
    end
    table.sort(floats)
    return orig, n, changed, floats
end

-- every file whose plain text differs from its original: { name, plain, n, bytes, floats }
function M.diff()
    local out = {}
    for name, f in pairs(M.files) do
        local plain, n, count, floats = changes(f)
        if plain then out[#out + 1] = { name = name, plain = plain, n = n, bytes = count, floats = floats, hash = f.hash } end
    end
    table.sort(out, function(x, y) return x.name < y.name end)
    return out
end

-- ---------------------------------------------------------------- passive stacking
-- Every armor with passive T also gets passive S's modifiers and weapon stat modifiers (their values as edited):
-- they are appended to T's block (payload: 56 bytes, the modifiers at +56, 16 bytes each, then the weapon stat
-- modifiers, 12 bytes each), so the file grows; the hash correction works at any length.
-- stacks: target passive id -> { source passive id, ... }; own_off: passive id -> true: its own modifiers left out
-- (only the stacked ones; none: the passive does nothing). Adds to / changes `changes` (from M.diff) in place.
local PASSIVE = 0x63CE0FEB
-- `add`'s modifiers appended to `mods`, but for the ids `mods` has already: the game applies an id once (Engineering
-- Kit + Integrated Explosives: +2 grenades, not +4), and the armory's preview of a passive holding an id twice crashes
-- the game (issue #66). The ids left out go to `dropped`.
local function append_mods(mods, add, dropped)
    local have, out = {}, { mods }
    for o = 1, #mods, 16 do have[mods:sub(o, o + 3)] = true end
    for o = 1, #add, 16 do
        local key = add:sub(o, o + 3)
        if have[key] then
            local b1, b2, b3, b4 = key:byte(1, 4)
            dropped[#dropped + 1] = string.format('%08X', ((b4 * 256 + b3) * 256 + b2) * 256 + b1)
        else
            have[key], out[#out + 1] = true, add:sub(o, o + 15)
        end
    end
    return table.concat(out)
end

-- The armory's preview of a passive lists at most 3 described modifiers (no native passive has more; a 4th crashes
-- the game, issue #74): past the 3rd, a modifier keeps its effect but loses its description id (+12). The ids
-- that lose it go to `hidden`.
local MAX_DESCRIBED = 3
local function cap_descriptions(mods, hidden)
    local out, shown = {}, 0
    for o = 1, #mods, 16 do
        local m = mods:sub(o, o + 15)
        if m:sub(13, 16) ~= '\0\0\0\0' then
            shown = shown + 1
            if shown > MAX_DESCRIBED then
                local b1, b2, b3, b4 = m:byte(1, 4)
                hidden[#hidden + 1] = string.format('%08X', ((b4 * 256 + b3) * 256 + b2) * 256 + b1)
                m = m:sub(1, 12) .. '\0\0\0\0'
            end
        end
        out[#out + 1] = m
    end
    return table.concat(out)
end

function M.stack(changes, stacks, log, own_off)
    log, stacks, own_off = log or function() end, stacks or {}, own_off or {}
    local any = next(own_off) ~= nil
    for _, list in pairs(stacks) do if #list > 0 then any = true end end
    if not any then return true end
    local f
    for _, file in pairs(M.files) do
        for _, h in ipairs(G.headers(file.p, file.n)) do if h.type == PASSIVE then f = file; break end end
        if f then break end
    end
    if not f then return nil, 'the armor passive file is not loaded' end
    local c
    for _, x in ipairs(changes) do if x.name == f.name then c = x end end
    if not c then
        local plain, n = open_base(f.cipher)
        if not plain then return nil, f.name .. ': ' .. tostring(n) end
        c = { name = f.name, plain = plain, n = n, bytes = 0, floats = {}, hash = f.hash }
        changes[#changes + 1] = c
        table.sort(changes, function(x, y) return x.name < y.name end)
    end
    local p, n = c.plain, c.n
    local hs = G.headers(p, n)
    -- every passive's modifiers and weapon stat modifiers, as edited (before any grows)
    local blocks = {}
    for _, h in ipairs(hs) do
        if h.type == PASSIVE and h.size >= 56 then
            local P = h.at + 24
            local mc, sc = u32(p, P + 24), u32(p, P + 40)
            local mo = mc > 0 and tonumber(ffi.cast(u64p, p + P + 16)[0]) or 56
            local so = sc > 0 and tonumber(ffi.cast(u64p, p + P + 32)[0]) or 56 + mc * 16
            if mo == 56 and so == 56 + mc * 16 and h.size == so + sc * 12 then
                blocks[u32(p, P)] = { mods = ffi.string(p + P + 56, mc * 16), stats = ffi.string(p + P + so, sc * 12) }
            end
        end
    end
    local out, done = { ffi.string(p, hs[1].at) }, 0
    for k, h in ipairs(hs) do
        local P = h.at + 24
        local id = h.type == PASSIVE and h.size >= 56 and u32(p, P)
        local own, list = id and blocks[id], id and stacks[id]
        local mods, stats, names = own and own.mods, own and own.stats, {}
        if own and own_off[id] then mods, stats = '', '' end
        for _, s in ipairs(own and list or {}) do
            if s ~= id and blocks[s] then
                local dropped = {}
                mods, stats = append_mods(mods, blocks[s].mods, dropped), stats .. blocks[s].stats
                names[#names + 1] = tostring(s)
                if #dropped > 0 then
                    log('passive ' .. s .. ' (stacked on ' .. id .. '): modifier ' .. table.concat(dropped, ', ') ..
                        ' left out, passive ' .. id .. ' has it already')
                end
            elseif s ~= id then
                log('passive ' .. s .. ' (stacked on ' .. id .. ') is not in this game\'s file: left out')
            end
        end
        local block_end = k < #hs and hs[k + 1].at or n
        if #names > 0 then
            local hidden = {}
            mods = cap_descriptions(mods, hidden)
            if #hidden > 0 then
                log('passive ' .. id .. ': modifier ' .. table.concat(hidden, ', ') .. ' not described in the armory' ..
                    ' (it lists ' .. MAX_DESCRIBED .. ' at most), still applied')
            end
        end
        if #names > 0 or (own and own_off[id]) then
            local head = ffi.new('uint8_t[80]')
            ffi.copy(head, p + h.at, 80)
            local payload = head + 24
            local mc, sc = #mods / 16, #stats / 12
            ffi.cast('uint32_t *', head + 12)[0] = 56 + #mods + #stats                           -- block size
            ffi.cast(u64p, payload + 16)[0] = mc > 0 and 56 or NONE
            ffi.cast('uint32_t *', payload + 24)[0] = mc
            ffi.cast(u64p, payload + 32)[0] = sc > 0 and 56 + #mods or NONE
            ffi.cast('uint32_t *', payload + 40)[0] = sc
            out[#out + 1] = ffi.string(head, 80) .. mods .. stats
            out[#out + 1] = ffi.string(p + P + h.size, block_end - P - h.size)                   -- any padding after
            log(string.format('passive %d: %s, stacked %s (%d modifiers, %d weapon stat modifiers)', id,
                own_off[id] and 'own effects off' or 'own effects on', #names > 0 and table.concat(names, ', ') or 'none',
                mc, sc))
            done = done + 1
        else
            out[#out + 1] = ffi.string(p + h.at, block_end - h.at)
        end
    end
    if done == 0 then return true end
    local s = table.concat(out)
    local grown = G.alloc(#s)
    ffi.copy(grown, s, #s)
    G.free(c.plain)
    -- the edited floats moved: the other headers' reserved bytes salt the hash correction
    c.plain, c.n, c.bytes, c.floats = grown, #s, c.bytes + #s - n, {}
    return true
end

-- ---------------------------------------------------------------- stratagem codes
-- StratagemInfo (rows of 400 bytes, the stratagem type at +0) +64: its call-in code, the payload offset of a u32
-- per arrow (1 up, 2 right, 3 down, 4 left), +72 the arrow count. A code no longer than the game's goes over its
-- own; a longer one is appended to its table, which grows (by whole 16 bytes, so the tables after keep their
-- alignment). codes: stratagem type -> { arrow, ... } (1 to 9: the game's code readers take 9 at most).
-- Adds to / changes `changes` (from M.diff) in place.
local STRATAGEM = 0x30EB6399
function M.codes(changes, codes, log)
    log, codes = log or function() end, codes or {}
    if not next(codes) then return true end
    local f
    for _, file in pairs(M.files) do
        for _, h in ipairs(G.headers(file.p, file.n)) do if h.type == STRATAGEM then f = file; break end end
        if f then break end
    end
    if not f then return nil, 'the stratagem file is not loaded' end
    local c
    for _, x in ipairs(changes) do if x.name == f.name then c = x end end
    if not c then
        local plain, n = open_base(f.cipher)
        if not plain then return nil, f.name .. ': ' .. tostring(n) end
        c = { name = f.name, plain = plain, n = n, bytes = 0, floats = {}, hash = f.hash }
        changes[#changes + 1] = c
        table.sort(changes, function(x, y) return x.name < y.name end)
    end
    local p, n = c.plain, c.n
    local hs = G.headers(p, n)
    local out, grown, done = { ffi.string(p, hs[1].at) }, 0, 0
    for k, h in ipairs(hs) do
        local P = h.at + 24
        local block_end = k < #hs and hs[k + 1].at or n
        local extra = {}   -- longer codes, appended after the payload
        if h.type == STRATAGEM and h.size >= 16 then
            local rows = u32(p, P + 8)
            for r = 0, rows - 1 do
                local R = P + 16 + r * 400
                local code = R + 400 <= P + h.size and codes[u32(p, R)]
                local ok = type(code) == 'table' and #code >= 1 and #code <= 9
                for _, a in ipairs(ok and code or {}) do ok = ok and (a == 1 or a == 2 or a == 3 or a == 4) end
                if code and not ok then
                    log('stratagem ' .. u32(p, R) .. ': code left as it is (1 to 9 arrows, 1-4 each)')
                elseif code then
                    local at, count = tonumber(ffi.cast(u64p, p + R + 64)[0]), u32(p, R + 72)
                    if count > 0 and (at < 16 + rows * 400 or at + count * 4 > h.size) then
                        log('stratagem ' .. u32(p, R) .. ': its code is not where it should be: left as it is')
                    else
                        if #code > count then   -- appended: 8-aligned, after the payload and earlier ones
                            local size = h.size
                            for _, s in ipairs(extra) do size = size + #s end
                            local pad = (8 - size % 8) % 8
                            extra[#extra + 1] = string.rep('\0', pad)
                            at = size + pad
                            ffi.cast(u64p, p + R + 64)[0] = at
                            local arrows = {}
                            for j, a in ipairs(code) do arrows[j] = string.char(a, 0, 0, 0) end
                            extra[#extra + 1] = table.concat(arrows)
                        else
                            for j, a in ipairs(code) do ffi.cast('uint32_t *', p + P + at)[j - 1] = a end
                        end
                        ffi.cast('uint32_t *', p + R + 72)[0] = #code
                        done = done + 1
                        log(string.format('stratagem %d: code of %d arrows (was %d)%s', u32(p, R), #code, count,
                            #code > count and ', appended to its table' or ''))
                    end
                end
            end
        end
        if #extra > 0 then
            local add = table.concat(extra)
            add = add .. string.rep('\0', (16 - #add % 16) % 16)
            local head = ffi.new('uint8_t[24]')
            ffi.copy(head, p + h.at, 24)
            ffi.cast('uint32_t *', head + 12)[0] = h.size + #add                                 -- block size
            out[#out + 1] = ffi.string(head, 24) .. ffi.string(p + P, h.size) .. add
            out[#out + 1] = ffi.string(p + P + h.size, block_end - P - h.size)                   -- any padding after
            grown = grown + #add
        else
            out[#out + 1] = ffi.string(p + h.at, block_end - h.at)
        end
    end
    c.bytes = c.bytes + done
    if grown == 0 then return true end
    local s = table.concat(out)
    local bigger = G.alloc(#s)
    ffi.copy(bigger, s, #s)
    G.free(c.plain)
    -- the edited floats moved: the other headers' reserved bytes salt the hash correction
    c.plain, c.n, c.floats = bigger, #s, {}
    return true
end

-- seal one changed file: { name, sealed } or nil, why
function M.build(change, log)
    log = log or function() end
    -- a one-table file whose changes hold no float to vary (whole numbers, zeros): nothing in it may vary for the
    -- hash correction, so its table grows by 16 zero bytes after everything it holds (the game reads only what
    -- its offsets name; grown tables load, as stacked passives do), and those vary instead
    local hs = G.headers(change.plain, change.n)
    if #change.floats == 0 and #hs == 1 and hs[1].at + 24 + hs[1].size == change.n then
        local n = change.n
        local salt = n + (8 - n % 8) % 8                -- a word of its own (the native search needs the words whole)
        local grown = G.alloc(salt + 16)               -- (zeroed)
        ffi.copy(grown, change.plain, n)
        ffi.cast('uint32_t *', grown + hs[1].at + 12)[0] = salt + 16 - hs[1].at - 24
        G.free(change.plain)
        change.plain, change.n, change.floats = grown, salt + 16, { salt }
        log(string.format('no float among the changes: the table grows by %d bytes for the hash correction', salt + 16 - n))
    end
    local ok, why
    if change.demolition_schemas then
        local Demo = require('demolition')
        local before = ffi.string(change.plain, change.n)
        local valid, slot = pcall(Demo.entity_hash_slot, before, change.demolition_schemas)
        if not valid then G.free(change.plain); return nil, tostring(slot) end
        ok, why = G.correct_numeric_slot(change.plain, change.n, change.hash, slot.host, slot.knob, log)
        if ok then
            local layout = slot.layout
            for index in pairs(layout.users) do
                local at = layout.block.payload + layout.array.offset + index * layout.row.size
                if ffi.string(change.plain + at, layout.row.size) ~= before:sub(at + 1, at + layout.row.size) then
                    ok, why = nil, 'a referenced wind-up record changed during hash correction'; break
                end
            end
        end
    else
        ok, why = G.correct(change.plain, change.n, change.hash, change.floats, log)
    end
    if not ok then G.free(change.plain); return nil, why end
    local sealed = G.seal(change.plain, change.n)
    local back, m = G.open_sealed(sealed)
    local good = back and m == change.n and ffi.C.memcmp(back, change.plain, m) == 0 and G.murmur64(back, m) == change.hash
    if back then G.free(back) end
    G.free(change.plain)
    if not good then return nil, 'read-back check failed' end
    return sealed
end

return M
