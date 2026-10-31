-- SHODAN Stat Editor Offline: the game's archives, read directly (no Filediver).
-- The game data folder (data\) holds its resources in archives: a "triad" per archive id (16 hex digits): the main
-- file (named by the id), and beside it <id>.gpu_resources and <id>.stream. Patches are <id>.patch_N (+ the same two
-- companions); the game loads them over the archive, in order.
-- Two editions:
--   * full: every archive is a loose file in data\;
--   * slim (Steam's current one): the archives are packed into data\bundles.NN.nxa, listed by data\bundles.nxa; a
--     few (updates, patches) still sit loose beside them, and a loose file wins.
-- bundles.nxa and the bundles are DSAR files: 32-byte header ('DSAR', +8 u32 chunk count), then 32 bytes a chunk
-- (u64 offset unpacked, u64 offset in the file, u32 size unpacked, u32 size packed, u8 packing: 0 stored, 3 LZ4).
-- bundles.nxa unpacked is a DSAA list: +12 u32 bundle count, +16 u32 archive count; from +24, 24 bytes an archive
-- (u64 size, u32 name offset, u32 entry count, u64 entries offset; an entry, 16 bytes: u32 offset in the archive,
-- +8 u32 the chunk's offset unpacked in the bundle, +15 u8 the bundle), then a u32 name offset per bundle.
-- An archive's main file: 72-byte header (u32 0xF0000011, u32 type count, u32 file count), 32 bytes a type, 80 bytes a
-- file: u64 name, u64 type, u64 main / stream / gpu offsets (+16 / +24 / +32), u32 main / stream / gpu sizes (+56 /
-- +60 / +64). Names and types are 8 raw bytes (little endian, as the game stores them).
-- Checked against the game of 2026-10-29 (slim edition): 30 bundles, 9725 archives, 3522 of them main files.
-- Plain Lua (5.1 / LuaJIT / 5.3): LZ4 through ffi when LuaJIT has it, else in Lua (the tests run that way).
local M = {}

local ok_ffi, ffi = pcall(require, 'ffi')
if not ok_ffi or not (rawget(_G, 'jit')) then ffi = nil end

local function u32(s, o) local a, b, c, d = s:byte(o + 1, o + 4); return a + b * 256 + c * 65536 + d * 16777216 end
local function u64(s, o) return u32(s, o) + u32(s, o + 4) * 4294967296 end
M.u32, M.u64 = u32, u64

-- 8 raw bytes as the 16 hex digits the editor writes (the u64's value, high half first) and back
function M.hex(raw) return string.format('%08X%08X', u32(raw, 4), u32(raw, 0)) end
function M.raw(hex)
    local hi, lo = tonumber(hex:sub(1, 8), 16), tonumber(hex:sub(9, 16), 16)
    local function le(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
    return le(lo) .. le(hi)
end

local function read_at(path, offset, n)
    local f = io.open(path, 'rb')
    if not f then return nil end
    f:seek('set', offset)
    local s = f:read(n)
    f:close()
    return s
end
M.read_at = read_at
local function exists(path) local f = io.open(path, 'rb'); if f then f:close(); return true end; return false end

-- ---------------------------------------------------------------- LZ4 (a block, no frame) of `size` bytes unpacked
local lz4
if ffi then
    local bit = require('bit')
    lz4 = function(src, size)
        local s, n = ffi.cast('const uint8_t *', src), #src
        local out = ffi.new('uint8_t[?]', size)
        local i, o = 0, 0
        while i < n do
            local token = s[i]; i = i + 1
            local lit = bit.rshift(token, 4)
            if lit == 15 then repeat local b = s[i]; i = i + 1; lit = lit + b until b ~= 255 end
            assert(i + lit <= n and o + lit <= size, 'LZ4: literals past the end')
            ffi.copy(out + o, s + i, lit)
            i, o = i + lit, o + lit
            if i >= n then break end
            local back = s[i] + s[i + 1] * 256; i = i + 2
            local len = token % 16
            if len == 15 then repeat local b = s[i]; i = i + 1; len = len + b until b ~= 255 end
            len = len + 4
            assert(back > 0 and back <= o and o + len <= size, 'LZ4: match out of range')
            if back >= len then ffi.copy(out + o, out + o - back, len)
            else for k = 0, len - 1 do out[o + k] = out[o - back + k] end end   -- overlapping: byte by byte
            o = o + len
        end
        assert(o == size, 'LZ4: wrong size')
        return ffi.string(out, size)
    end
else
    lz4 = function(src, size)
        local parts = {}
        local buf, blen = {}, 0
        local i, n = 1, #src
        while i <= n do
            local token = src:byte(i); i = i + 1
            local lit = math.floor(token / 16)
            if lit == 15 then repeat local b = src:byte(i); i = i + 1; lit = lit + b until b ~= 255 end
            assert(i + lit - 1 <= n, 'LZ4: literals past the end')
            for k = 0, lit - 1 do blen = blen + 1; buf[blen] = src:byte(i + k) end
            i = i + lit
            if i > n then break end
            local back = src:byte(i) + src:byte(i + 1) * 256; i = i + 2
            local len = token % 16
            if len == 15 then repeat local b = src:byte(i); i = i + 1; len = len + b until b ~= 255 end
            len = len + 4
            assert(back > 0 and back <= blen, 'LZ4: match out of range')
            for _ = 1, len do blen = blen + 1; buf[blen] = buf[blen - back] end
        end
        assert(blen == size, 'LZ4: wrong size')
        local unpack = table.unpack or unpack
        for a = 1, blen, 4096 do parts[#parts + 1] = string.char(unpack(buf, a, math.min(blen, a + 4095))) end
        return table.concat(parts)
    end
end
M.lz4 = lz4

-- a DSAR file's chunks: { unpacked offset, file offset, unpacked size, packed size, packing }
local function dsar(path)
    local head = assert(read_at(path, 0, 32), 'cannot read ' .. path)
    assert(head:sub(1, 4) == 'DSAR', path .. ': not a DSAR file')
    local count = u32(head, 8)
    local raw = assert(read_at(path, 32, count * 32), path .. ': truncated chunk list')
    assert(#raw == count * 32, path .. ': truncated chunk list')
    local out = {}
    for k = 0, count - 1 do
        local o = k * 32
        out[k + 1] = { u64(raw, o), u64(raw, o + 8), u32(raw, o + 16), u32(raw, o + 20), raw:byte(o + 25) }
    end
    return out
end
local function chunk(path, c)
    local packed = assert(read_at(path, c[2], c[4]), 'cannot read ' .. path)
    if c[5] == 0 then return packed end
    assert(c[5] == 3, 'unknown packing ' .. tostring(c[5]))
    return lz4(packed, c[3])
end

-- ---------------------------------------------------------------- the store: an archive's bytes, from either edition
local Store = {}
Store.__index = Store

-- data: the game's data folder (…/Helldivers 2/data). The slim edition's list is read at once (about 15 MB).
function M.open(data)
    data = data:gsub('\\', '/'):gsub('/+$', '')
    local self = setmetatable({ data = data, archives = {}, bundles = {}, chunks = {}, cache = {}, cached = {},
                                slim = false, dirs = {} }, Store)
    local list = data .. '/bundles.nxa'
    if exists(list) then
        local parts = {}
        for _, c in ipairs(dsar(list)) do parts[#parts + 1] = chunk(list, c) end
        local d = table.concat(parts)
        assert(d:sub(1, 4) == 'DSAA', 'bundles.nxa: not a DSAA list')
        local bundles, count = u32(d, 12), u32(d, 16)
        assert(24 + 24 * count + 4 * bundles <= #d, 'bundles.nxa: truncated')
        for k = 0, count - 1 do
            local at = 24 + 24 * k
            local name = d:match('^[^%z]*', u32(d, at + 8) + 1)
            self.archives[name] = { size = u64(d, at), entries = u32(d, at + 12), entries_at = u64(d, at + 16) }
        end
        for k = 0, bundles - 1 do self.bundles[k] = d:match('^[^%z]*', u32(d, 24 + 24 * count + 4 * k) + 1) end
        self.list, self.slim = d, true
    end
    return self
end

-- whether an archive file (main, .gpu_resources, .stream, a patch) exists: loose, or in a bundle
function Store:has(name)
    return exists(self.data .. '/' .. name) or self.archives[name] ~= nil
end

-- n bytes at `offset` in an archive file (a loose file first)
function Store:read(name, offset, n)
    if n == 0 then return '' end
    local loose = read_at(self.data .. '/' .. name, offset, n)
    if loose then
        assert(#loose == n, name .. ': truncated')
        return loose
    end
    local a = assert(self.archives[name], 'archive ' .. name .. ' not found')
    local d, pick = self.list, nil
    local lo, hi = 0, a.entries - 1   -- (entries by offset: the last at or before `offset`)
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if u32(d, a.entries_at + 16 * mid) <= offset then pick, lo = mid, mid + 1 else hi = mid - 1 end
    end
    assert(pick, 'archive ' .. name .. ': no entry for offset ' .. offset)
    local e = a.entries_at + 16 * pick
    local at, unpacked, b = u32(d, e), u32(d, e + 8), d:byte(e + 16)
    local path = self.data .. '/' .. assert(self.bundles[b], 'bundle ' .. tostring(b))
    local cs = self.chunks[b]
    if not cs then
        cs = dsar(path); self.chunks[b] = cs
        cs.by = {}
        for k, c in ipairs(cs) do cs.by[c[1]] = k end
    end
    local i = assert(cs.by[unpacked], 'archive ' .. name .. ': chunk not found')
    local out, have = {}, 0
    while at + have < offset + n do
        local c = assert(cs[i], 'archive ' .. name .. ': past the last chunk')
        local key = b .. ':' .. i
        local s = self.cache[key]
        if not s then
            s = chunk(path, c)
            -- a few chunks kept (the directory, then the files near each other are read in turn)
            self.cached[#self.cached + 1] = key; self.cache[key] = s
            if #self.cached > 128 then self.cache[table.remove(self.cached, 1)] = nil end
        end
        out[#out + 1], have, i = s, have + #s, i + 1
    end
    local s = table.concat(out)
    return s:sub(offset - at + 1, offset - at + n)
end

-- an archive's files: { name = 8 raw bytes, type = 8 raw bytes, main = {offset, size}, stream = {..}, gpu = {..} }
-- in the archive's order, and .by[name .. type]
function Store:directory(name)
    if self.dirs[name] then return self.dirs[name] end
    local head = self:read(name, 0, 72)
    assert(u32(head, 0) == 0xF0000011, name .. ': not an archive')
    local types, files = u32(head, 4), u32(head, 8)
    assert(types <= 100000 and files <= 10000000, name .. ': implausible directory')
    local list = self:read(name, 72, 32 * types + 80 * files)
    local out = { by = {} }
    for k = 0, files - 1 do
        local o = 32 * types + 80 * k
        local f = { name = list:sub(o + 1, o + 8), type = list:sub(o + 9, o + 16),
                    main = { u64(list, o + 16), u32(list, o + 56) }, stream = { u64(list, o + 24), u32(list, o + 60) },
                    gpu = { u64(list, o + 32), u32(list, o + 64) } }
        out[#out + 1] = f
        out.by[f.name .. f.type] = f
    end
    self.ndirs = (self.ndirs or 0) + 1
    if self.ndirs > 64 then self.dirs, self.ndirs = {}, 1 end
    self.dirs[name] = out
    return out
end

-- a resource of an archive (by its 16 raw bytes: name .. type): { name, type, main, gpu, stream } (the parts it has),
-- nil when the archive does not hold it
function Store:resource(archive, key)
    local f = self:directory(archive).by[key]
    if not f then return nil end
    local r = { name = f.name, type = f.type, main = self:read(archive, f.main[1], f.main[2]) }
    r.stream = f.stream[2] > 0 and self:read(archive .. '.stream', f.stream[1], f.stream[2]) or ''
    r.gpu = f.gpu[2] > 0 and self:read(archive .. '.gpu_resources', f.gpu[1], f.gpu[2]) or ''
    return r
end

-- every main archive's id (16 lowercase hex digits; loose ones and bundled ones; not the patches)
function Store:mains(list_files)
    local seen, out = {}, {}
    for name in pairs(self.archives) do
        if #name == 16 and name:match('^%x+$') and not seen[name] then seen[name] = true; out[#out + 1] = name end
    end
    for _, name in ipairs(list_files and list_files(self.data, '????????????????') or {}) do
        name = name:lower()
        if #name == 16 and name:match('^%x+$') and not seen[name] then seen[name] = true; out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------- an index: where resources of some types are
-- types: a set of 8 raw type bytes. Returns index[name .. type] = { archive ids }, built by reading every main
-- archive's directory once. cache: a file to keep it in for the same game files (stamp: a text naming them).
function M.index(store, types, cache, stamp, list_files, progress)
    if cache then
        local f = io.open(cache, 'rb')
        local s = f and f:read('*a'); if f then f:close() end
        if s and s:sub(1, 4) == 'SAX1' then
            local sl = u32(s, 4)
            if s:sub(9, 8 + sl) == stamp then
                local at, out = 8 + sl, {}
                local na = u32(s, at); at = at + 4
                local names = {}
                for k = 1, na do names[k] = s:sub(at + 1, at + 16); at = at + 16 end
                local ne = u32(s, at); at = at + 4
                for _ = 1, ne do
                    local key, a = s:sub(at + 1, at + 16), u32(s, at + 16)
                    at = at + 20
                    local t = out[key]; if not t then t = {}; out[key] = t end
                    t[#t + 1] = names[a + 1]
                end
                return out
            end
        end
    end
    local out, mains = {}, store:mains(list_files)
    for k, name in ipairs(mains) do
        local ok, dir = pcall(store.directory, store, name)
        if ok then
            for _, f in ipairs(dir) do
                if types[f.type] then
                    local key = f.name .. f.type
                    local t = out[key]; if not t then t = {}; out[key] = t end
                    t[#t + 1] = name
                end
            end
        end
        store.dirs = {}
        if progress and k % 200 == 0 then progress(k, #mains) end
    end
    if cache then
        local names, at, entries = {}, {}, {}
        for key, list in pairs(out) do
            for _, a in ipairs(list) do
                if not at[a] then names[#names + 1] = a; at[a] = #names - 1 end
                entries[#entries + 1] = key .. string.char(at[a] % 256, math.floor(at[a] / 256) % 256, math.floor(at[a] / 65536) % 256, 0)
            end
        end
        local function le(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
        local blob = 'SAX1' .. le(#stamp) .. stamp .. le(#names) .. table.concat(names) .. le(#entries) .. table.concat(entries)
        local f = io.open(cache .. '.new', 'wb')
        if f then f:write(blob); f:close(); os.remove(cache); os.rename(cache .. '.new', cache) end
    end
    return out
end

M.dsar = dsar
return M
