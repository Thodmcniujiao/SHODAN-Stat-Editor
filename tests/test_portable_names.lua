-- Portable Names: the package folder is read instead of %LOCALAPPDATA%.
local F = require('preset_files')
local N = require('entity_names')
local R = require('record_names')
local I = require('install')

local root = assert(TEST_ROOT) .. '/offline/Names'
assert(F.read(root .. '/EntityNames/未分类.json'), 'package EntityNames missing')
assert(F.read(root .. '/TypeIdNames/projectile.json'), 'package TypeIdNames missing')

local cfg = N.load(root .. '/EntityNames')
local entities = 0
for _ in pairs(cfg.entities) do entities = entities + 1 end
assert(entities == 3465, 'entity count ' .. entities)
assert(cfg.entities.E006E44327BB953FE.name == 'GL-15 驱逐者（主武器，模型）', 'GL-15 name')
assert(cfg.entities.E0002BA767DF856F3.name == 'Marauder', 'non-table entity name')
for rid, item in pairs(cfg.entities) do
    assert(not item.name:find('\r', 1, true) and not item.name:find('\n', 1, true), 'control char ' .. rid)
end
-- entity_catalog uses N.open: with existing group files it must load the package unchanged.
local legacy = {categories = {{id = 'other', name = 'other', order = 1}}, default_category = 'other', entities = {}}
local entity_before = F.read(root .. '/EntityNames/未分类.json')
local opened = N.open(root .. '/EntityNames', legacy, {})
local opened_count = 0
for _ in pairs(opened.entities) do opened_count = opened_count + 1 end
assert(opened_count == 3465 and opened.entities.E006E44327BB953FE.name == 'GL-15 驱逐者（主武器，模型）', 'N.open package')
assert(F.read(root .. '/EntityNames/未分类.json') == entity_before, 'package EntityNames changed')

-- An app-data folder that has no TypeIdNames: the package folder must be used.
local dir = assert(TEST_WORK) .. '/portable-names-app'
I.mkdirs(dir)
local before = F.read(root .. '/TypeIdNames/projectile.json')
local count, errors = R.load(dir, root)
assert(#errors == 0, tostring(errors[1]))
assert(count == 1748, 'TypeID count ' .. count)
assert(R.folder == root .. '/TypeIdNames', 'package folder not selected: ' .. tostring(R.folder))
assert(R.name('projectile', 2) == '激进先锋 能量霰弹枪', 'projectile 2')
assert(R.name('damage', 20) == 'FLAM-40 火焰喷射器 (支援武器, 模型)', 'damage 20')
assert(R.name('explosion', 8) == 'G-7 菠萝 (投掷物, 模型)', 'explosion 8')
assert(R.name('status', 1) == 'Blind', 'status 1')
assert(R.name('bombardment', 0) ~= nil, 'carried bombardment name')
assert(F.read(root .. '/TypeIdNames/projectile.json') == before, 'loader rewrote the package')
local count2, errors2 = R.reload(dir, root)
assert(#errors2 == 0 and count2 == 1748 and R.folder == root .. '/TypeIdNames', 'reload')
assert(F.read(root .. '/TypeIdNames/projectile.json') == before, 'reload rewrote the package')
print('PASS: portable Names loaded directly from offline/Names (3465 entities, 1748 TypeID names)')
