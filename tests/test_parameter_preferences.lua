local P = require('parameter_preferences')
local J = require('json_data')
local files, fail = {}, nil
local fs = {
    read = function(p) return files[p] end,
    write = function(p, s) if fail == 'write' then return nil, 'write failed' end; files[p] = s; return true end,
    move = function(a, b) if fail == 'move' then return nil, 'move failed' end; files[b], files[a] = files[a], nil; return true end,
    remove = function(p) files[p] = nil end,
}
local tables = { [11] = { records_layout = { data_offset = 64, stride = 32, record_count = 3 } },
    [12] = { records_layout = { data_offset = 64, stride = 32, record_count = 3 } } }
local function row(kind, offset, id)
    return { component = 'Unit', section = 'base', id = id or 'health', label = 'Health', parts = {
        { field = { kind = kind, offset = offset, storage = 'u32' } } } }
end
local c = { folder = 'copy/Data', fs = fs, mkdir = function() return true end,
    identity = function(p, r) return P.identity(p, r, tables, {}) end,
    favorite_label = function() return '收藏' end, empty_label = function() return 'Right-click' end }
local page = { hash = 'one', rows = { row(11, 68), row(11, 72, 'armor') } }
local other = { hash = 'two', rows = { row(11, 100) } }
local p = P.new(c)
assert(p:key(page, page.rows[1]) == p:key(other, other.rows[1]), 'different entities/indices must share component field preferences')
assert(p:key(page, page.rows[1]) ~= p:key(page, row(12, 68)), 'component types collided')
local bit = row(11, 68); bit.parts[1].field.mask = 2
assert(p:key(page, bit) ~= p:key(page, page.rows[1]), 'packed fields collided')
local key = p:key(page, page.rows[1]); local health = page.rows[1]
p:refresh(page)
assert(#page.rows == 3 and page.rows[1].parameter_hint and page.rows[1].section_of() == '收藏')
assert(p:label(page, page.rows[1]) == '' and not p:key(page, page.rows[1]))
assert(p:set(page, health, 'favorite', true)); p:refresh(page, health)
assert(#page.rows == 3 and page.rows[1].parameter_favorite and page.rows[1].parts == health.parts)
assert(page.rows[2] == health and p:label(page, health) == '★ Health')
assert(p:set(page, health, 'name', '测试名称 # " /')); p:refresh(page)
assert(p:label(other, other.rows[1]) == '★ 测试名称 # " /')
local saved = files[p.path]; local loaded = P.new(c)
assert(loaded:get(other, other.rows[1]).name == '测试名称 # " /', 'UTF-8 name did not survive JSON reload')
local rebased = row(11, 228); tables[11].records_layout.data_offset = 224
assert(P.identity(page, rebased, tables, {}) == key, 'record-array relocation changed parameter identity')
tables[11].records_layout.data_offset = 64
for _, mode in ipairs({ 'write', 'move' }) do
    fail = mode
    assert(not p:set(page, health, 'name', 'lost'))
    assert(files[p.path] == saved and p:get(page, health).name == '测试名称 # " /', 'failed save lost preferences')
end
fail = nil
assert(p:set(page, health, 'name', '')); assert(p:get(page, health).favorite and not p:get(page, health).name)
assert(p:set(page, health, 'favorite', false)); p:refresh(page, page.rows[1]); assert(not p:get(page, health))
for _ = 1, 5 do p:refresh(page) end
assert(#page.rows == 3 and page.rows[1].parameter_hint, 'projection accumulated duplicate rows')
local closed = { hash = 'closed', rows = { { component = 'Unit', collapsed_component = true, parts = {} } } }
p:refresh(closed); assert(#closed.rows == 1, 'collapsed component must stay lazy')
assert(p:set(page, health, 'favorite', true))
local health_page = { hash = 'health', health_full = true, all_component_rows = { health }, rows = closed.parameter_raw_rows }
p:refresh(health_page)
assert(#health_page.rows == 2 and health_page.rows[1].parameter_source == health,
    'single-component favorites must be above closed parameter subgroups')
local mixed = { hash = 'mixed', rows = { row(11, 68), row(12, 68) } }; mixed.rows[2].component = 'Health'
p:refresh(mixed)
assert(#mixed.rows == 4 and mixed.rows[1].component == 'Unit' and mixed.rows[3].component == 'Health')
local action = { hash = 'actions', rows = { { id = 'run', component = 'Preload', custom_action = function() error('hint ran an action') end }, row(12, 72) } }
action.rows[2].component = 'Preload'; p:refresh(action)
assert(action.rows[1].parameter_hint and not action.rows[1].custom_action and not action.rows[1].custom_edit,
    'empty hint inherited the original row editing callbacks')
files[p.path] = '{broken'; local broken = P.new(c)
assert(broken.error and not broken:set(page, health, 'name', 'overwrite'))
assert(files[p.path] == '{broken', 'malformed portable data was overwritten')
print('PASS: component-scoped favorites/names, shared field identity, relocation, JSON restart, atomic failure rollback, lazy presentation')
