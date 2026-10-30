-- The shared StratagemInfo field classification (all pages use this table).
local S = require('stratagem_components')
local seen = {}
local function check(name, where)
    local g = S.group(name)
    assert(g, where .. ': ' .. name .. ' has no group')
    assert(g.name and #g.name == 3, where .. ': group has no three-language name')
    seen[#seen + 1] = name
end
for _, f in ipairs(S.FIELDS) do check(f[1], 'FIELDS') end
for _, f in ipairs(S.EXTRA) do check(f[1], 'EXTRA') end
for _, f in ipairs(S.HASHES) do check(f[1], 'HASHES') end
for _, f in ipairs(S.STRINGS) do check(f[1], 'STRINGS') end
for _, f in ipairs(S.ARRAYS) do check(f[1], 'ARRAYS') end
check('Button1', 'pattern')
check('Button9', 'pattern')
check('Payload1', 'pattern')
check('Field_000', 'pattern')
assert(S.group('Category').id == 'category')
assert(S.group('Cooldown').id == 'timing')
assert(S.group('Button3').id == 'callin')
assert(S.group('Payload2').id == 'payload')
assert(S.group('Field_999').id == 'unknown')
assert(#S.GROUPS == 11, 'group count ' .. #S.GROUPS)
for i, g in ipairs(S.GROUPS) do
    assert(g.id and g.name and #g.name == 3, 'bad group ' .. i)
end
print('PASS: all StratagemInfo fields map to one shared group (' .. #seen .. ' fields, ' .. #S.GROUPS .. ' groups)')
