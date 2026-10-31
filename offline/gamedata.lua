-- SHODAN Stat Editor Offline: the game's data files (data/game/generated_*.dl_bin).
-- A file is a NaCl sealed box (X25519 + XSalsa20-Poly1305) of a run of LDLD blocks: the settings tables the game
-- loads into memory at start. game.dll holds the seeded murmur64 of every file's plain text, so an edited file
-- must keep its hash: the caller appends an aligned tail word and solves it exactly.
local ffi = require('ffi')
local bit = require('bit')

ffi.cdef [[
int sodium_init(void);
int crypto_box_seal(unsigned char *c, const unsigned char *m, unsigned long long mlen, const unsigned char *pk);
int crypto_box_seal_open(unsigned char *m, const unsigned char *c, unsigned long long clen,
                         const unsigned char *pk, const unsigned char *sk);
void *VirtualAlloc(void *address, size_t size, uint32_t type, uint32_t protect);
int VirtualFree(void *address, size_t size, uint32_t type);
void *memcpy(void *dst, const void *src, size_t n);
int memcmp(const void *a, const void *b, size_t n);
]]

local M = {}
local here = (debug.getinfo(1, 'S').source:match('^@(.*[/\\])') or '')
local sodium
for _, at in ipairs({ here .. 'runtime/libsodium.dll', here .. 'libsodium.dll', here .. '../libsodium.dll', 'libsodium.dll' }) do
    local ok, lib = pcall(ffi.load, at)
    if ok then sodium = lib; break end
end
assert(sodium, 'libsodium.dll not found')
assert(sodium.sodium_init() >= 0, 'libsodium did not start')

local function unhex(h) return (h:gsub('%x%x', function(c) return string.char(tonumber(c, 16)) end)) end
local PK = unhex('2dc9aa7c30e6eed5f7fd0e0e95c7287299b126f79520cc41de750982ee7ff50c')
local SK = unhex('a0296b81310b58f013d8a9b343a1c292008003dfd9ab15fcf351543048b49b64')
local SEALBYTES = 48
M.SEALBYTES = SEALBYTES

local MUL = 0xC6A4A7935BD1E995ULL
local INV = 0x5F7A0EA7E59B19BDULL   -- MUL^-1 mod 2^64
local SEED = 16045690983977655786ULL
assert(MUL * INV == 1ULL, 'inverse')
local u64p = ffi.typeof('uint64_t *')
local u8p = ffi.typeof('uint8_t *')

-- ---------------------------------------------------------------- buffers (VirtualAlloc: page aligned, private)
local MEM_COMMIT_RESERVE, MEM_RELEASE, PAGE_READWRITE = 0x3000, 0x8000, 0x04
function M.alloc(size)
    local p = ffi.C.VirtualAlloc(nil, math.max(size, 1), MEM_COMMIT_RESERVE, PAGE_READWRITE)
    assert(p ~= nil, 'out of memory (' .. size .. ' bytes)')
    return ffi.cast(u8p, p)
end
function M.free(p) if p ~= nil then ffi.C.VirtualFree(p, 0, MEM_RELEASE) end end

function M.read_file(path)
    local f = io.open(path, 'rb')
    if not f then return nil, 'cannot open ' .. path end
    local s = f:read('*a'); f:close()
    return s
end

-- ---------------------------------------------------------------- crypto
-- the plain text of a sealed file, in a new buffer (never a Lua string: a string copy of the tables in memory
-- would be found by Stat Editor's table scan as a second copy)
function M.open_sealed(cipher)
    local n = #cipher - SEALBYTES
    if n < 0 then return nil, 'too short' end
    local p = M.alloc(n)
    if sodium.crypto_box_seal_open(p, cipher, #cipher, PK, SK) ~= 0 then M.free(p); return nil, 'not a game data file' end
    return p, n
end
function M.seal(p, n)
    local c = ffi.new('uint8_t[?]', n + SEALBYTES)
    assert(sodium.crypto_box_seal(c, p, n, PK) == 0, 'seal failed')
    return ffi.string(c, n + SEALBYTES)
end

-- ---------------------------------------------------------------- murmur64 (seeded, 64-bit words)
local function mix(v) v = v * MUL; v = bit.bxor(v, bit.rshift(v, 47)); return v * MUL end
local function unmix(v) v = v * INV; v = bit.bxor(v, bit.rshift(v, 47)); return v * INV end
M.mix, M.unmix = mix, unmix

-- the state after hashing the words at [a, b) (a, b multiples of 8)
local function forward(h, p, a, b)
    local w = ffi.cast(u64p, p)
    for i = a / 8, b / 8 - 1 do
        local v = w[i] * MUL; v = bit.bxor(v, bit.rshift(v, 47)); v = v * MUL
        h = bit.bxor(h, v) * MUL
    end
    return h
end
local function tail_word(p, n)
    local t, whole = 0ULL, n - n % 8
    for i = n - 1, whole, -1 do t = bit.bor(bit.lshift(t, 8), p[i] + 0ULL) end
    return t, whole
end
function M.murmur64(p, n)
    local h = bit.bxor(SEED, (n + 0ULL) * MUL)
    local t, whole = tail_word(p, n)
    h = forward(h, p, 0, whole)
    if whole < n then h = bit.bxor(h, t) * MUL end
    h = bit.bxor(h, bit.rshift(h, 47)); h = h * MUL; h = bit.bxor(h, bit.rshift(h, 47))
    return h
end
-- the state right after the last whole word, for a final hash `target`
local function before_final(target, p, n)
    local h = target
    h = bit.bxor(h, bit.rshift(h, 47)); h = h * INV; h = bit.bxor(h, bit.rshift(h, 47))
    local t, whole = tail_word(p, n)
    if whole < n then h = bit.bxor(h * INV, t) end
    return h, whole
end
function M.hex64(v) return (string.format('%016x', v):gsub('ULL', '')) end
local function le64(v)
    local s = {}
    for i = 0, 7 do s[i + 1] = string.char(tonumber(bit.band(bit.rshift(v, i * 8), 0xFF))) end
    return table.concat(s)
end
M.le64 = le64

-- ---------------------------------------------------------------- blocks
local NEEDLE = 'LDLD\1\0\0\0'
local function u32(p, o) return ffi.cast('uint32_t *', p + o)[0] end
M.u32 = u32
-- every block: { at = header offset, type, size }; the payload is at at + 24
function M.headers(p, n)
    local out, at = {}, nil
    for i = 0, math.min(n, 64) - 8 do
        if ffi.string(p + i, 8) == NEEDLE then at = i; break end
    end
    while at and at + 24 <= n do
        local typ, size = u32(p, at + 8), u32(p, at + 12)
        out[#out + 1] = { at = at, type = typ, size = size }
        local nxt = at + 24 + size
        at = nil
        for i = nxt, math.min(n, nxt + 64) - 8 do   -- blocks follow back to back (or after a little padding)
            if ffi.string(p + i, 8) == NEEDLE then at = i; break end
        end
    end
    return out
end
-- a game original: every header's reserved bytes zero (edited files carry a hash correction there)
function M.pristine(p, n)
    for _, h in ipairs(M.headers(p, n)) do
        if p[h.at + 16] ~= 1 then return false end
        for k = 17, 23 do if p[h.at + k] ~= 0 then return false end end
    end
    return true
end
-- undo another tool's hash correction (every header's reserved bytes back to flag 1 and zeros), so this editor's
-- tail correction can start from clean headers; true if there was one
function M.clear_correction(p, n)
    local cleared = false
    for _, h in ipairs(M.headers(p, n)) do
        if p[h.at + 16] ~= 1 then p[h.at + 16], cleared = 1, true end
        for k = 17, 23 do if p[h.at + k] ~= 0 then p[h.at + k], cleared = 0, true end end
    end
    return cleared
end

-- ---------------------------------------------------------------- hash correction
-- The caller appends a private, aligned word after all referenced table data.
-- Inverting Murmur64 solves it directly; no live parameter or header flag varies.
function M.correct_tail(p, n, target)
    if n < 8 or n % 8 ~= 0 then return nil, 'invalid checksum tail alignment' end
    local h = forward(bit.bxor(SEED, (n + 0ULL) * MUL), p, 0, n - 8)
    ffi.cast(u64p, p + n - 8)[0] = unmix(bit.bxor(before_final(target, p, n) * INV, h))
    if M.murmur64(p, n) ~= target then return nil, 'tail checksum did not verify' end
    return true
end

-- ---------------------------------------------------------------- game files
function M.game_dll_has(dll, hash) return dll:find(le64(hash), 1, true) ~= nil end

return M
