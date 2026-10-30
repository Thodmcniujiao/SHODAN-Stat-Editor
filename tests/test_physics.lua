-- offline/physics.lua (vehicle handling, exosuit movement, enemy animation files) and game_texts.merge (the patch
-- they go into), on a fake archive store: the files the panel asks for read into one buffer (missing and repeated
-- names skipped, 16-byte aligned), only changed ones patched, into the patch over the base archive, merged with what
-- that patch already gets.
--   python tests/run_lua.py tests/test_physics.lua   (no game files needed; texlua: a small ffi stand-in)
if not pcall(require, 'ffi') then   -- (texlua has no ffi: the few calls physics.lua makes, on a Lua byte array)
    local mt = {}
    local function ptr(buf, off) return setmetatable({ buf = buf, off = off }, mt) end
    mt.__add = function(p, n) return ptr(p.buf, p.off + n) end
    package.preload.ffi = function()
        return {
            new = function(_, n) local b = { n = n }; for i = 0, n - 1 do b[i] = 0 end; return ptr(b, 0) end,
            copy = function(dst, src, n) for i = 1, n do dst.buf[dst.off + i - 1] = src:byte(i) end end,
            string = function(p, n) local t = {}; for i = 0, n - 1 do t[#t + 1] = string.char(p.buf[p.off + i]) end; return table.concat(t) end,
            cast = function(_, p) return 4096 + p.off end,
        }
    end
end
local ffi = require('ffi')
local A = require('archives')
local P = require('physics')
local T = require('game_texts')
local PH, SM = P.PHYSICS, P.STATE_MACHINE
local function key(name, typ) return A.raw(name) .. A.raw(typ) end
local files = {   -- archive -> key -> resource
    aaaaaaaaaaaaaaaa = { [key('CC21C7FFD3EBEFB9', PH)] = { main = string.rep('\1', 21), gpu = '', stream = '' } },
    bbbbbbbbbbbbbbbb = { [key('79E4B3D2DA5E45E3', SM)] = { main = string.rep('\2', 40), gpu = 'g', stream = '' } },
}
local store = {
    has = function(_, name) return name == P.BASE or files[name] ~= nil end,
    resource = function(_, archive, k) return files[archive] and files[archive][k] end,
}
local index = { [key('CC21C7FFD3EBEFB9', PH)] = { 'aaaaaaaaaaaaaaaa' }, [key('79E4B3D2DA5E45E3', SM)] = { 'bbbbbbbbbbbbbbbb', 'cccccccccccccccc' } }
local logged = {}
local host = P.setup(store, index, function(t) logged[#logged + 1] = t end)
assert(host.base == nil and type(host.load) == 'function')
local base = host.load({ 'CC21C7FFD3EBEFB9.' .. PH, '79e4b3d2da5e45e3.' .. SM, '79E4B3D2DA5E45E3.' .. SM,
                         '1111111111111111.' .. PH, 'not a name' })
assert(base and host.base == base, 'a base address')
local a, b = host.files['79E4B3D2DA5E45E3.' .. SM], host.files['CC21C7FFD3EBEFB9.' .. PH]
assert(a and b and not host.files['1111111111111111.' .. PH], 'the two files the game has')
assert(a.at == 0 and a.size == 40 and b.at == 48 and b.size == 21, 'sorted, 16-byte aligned')
assert(host.load({}) == base, 'loaded once')
assert(#P.changed() == 0, 'nothing changed yet')
-- the panel writes a value into the vehicle's file
ffi.copy(P.buffer + b.at + 4, '\9\9', 2)
local list = P.changed()
assert(#list == 1 and list[1].id == 'CC21C7FFD3EBEFB9.' .. PH and list[1].main == '\1\1\1\1\9\9' .. string.rep('\1', 15))
assert(list[1].name == A.raw('CC21C7FFD3EBEFB9') and list[1].type == A.raw(PH) and list[1].gpu == nil)
-- into the patch over the base archive, through game_texts.merge (UA: a stand-in archive writer, as unit_aliases')
local UA = {}
function UA.archive(resources)
    local out = {}
    for _, r in ipairs(resources) do out[#out + 1] = A.hex(r.name) .. A.hex(r.type) .. '=' .. r.main .. ';' end
    return { main = table.concat(out), gpu = '', stream = '' }
end
function UA.read_archive(main)
    local back = {}
    for n, t, m in main:gmatch('(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)=([^;]*);') do
        back[A.raw(n) .. A.raw(t)] = { name = A.raw(n), type = A.raw(t), main = m, gpu = '', stream = '' }
    end
    return back
end
local strings = { name = A.raw('2222222222222222'), type = A.raw(T.STRINGS), main = 'texts' }
local writes = {}
T.merge(writes, P.BASE, { strings }, {}, '/nowhere', UA, function(path) return path:match('patch_0$') ~= nil end)
assert(writes[P.BASE .. '.patch_1'], 'the next free patch number (patch_0 is another mod\'s)')
local done = P.add_to(writes, {}, '/nowhere', UA, function() return false end, T.merge)
assert(#done == 1)
local back = UA.read_archive(writes[P.BASE .. '.patch_1'])
assert(back[strings.name .. strings.type].main == 'texts', 'the strings stay in the patch')
assert(back[list[1].name .. list[1].type].main == list[1].main, 'the vehicle file joins them')
-- written again (a second install): replaced by name and type, not repeated
ffi.copy(P.buffer + b.at + 4, '\8', 1)
P.add_to(writes, {}, '/nowhere', UA, function() return false end, T.merge)
local n = 0
for k, r in pairs(UA.read_archive(writes[P.BASE .. '.patch_1'])) do n = n + 1; if k == list[1].name .. list[1].type then assert(r.main:sub(5, 6) == '\8\9') end end
assert(n == 2, 'two files in the patch')
-- the editor's own patch is reused when nothing is being written yet
local own = {}
T.merge(own, P.BASE, { strings }, { [P.BASE .. '.patch_3'] = true }, '/nowhere', UA, function() return false end)
assert(own[P.BASE .. '.patch_3'], 'the owned patch')
print('physics: ok (files read once by the index, aligned, changes found, patched over the base archive with the texts)')
