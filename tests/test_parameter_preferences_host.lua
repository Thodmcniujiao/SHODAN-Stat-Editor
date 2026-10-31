-- Real desktop host, real component rows and controls, isolated portable data.
local app = os.getenv('SHODAN_TEST_APP')
if app then package.path = app .. '/?.lua;' .. package.path; SHODAN_DATA_DIRECTORY = nil; SHODAN_PRESET_DIRECTORY = nil end
local ffi = require('ffi')
local I, S, H = require('install'), require('engine_shim'), require('hostdata')
I.mkdirs(I.home); I.mkdirs(TEST_WORK)
assert(I.home:gsub('\\', '/'):sub(1, #TEST_WORK + 1) == TEST_WORK .. '/')
if not app then require('user_paths').names = TEST_WORK .. '/program/Names' end
require('portable_io_guard')
I.find_game = function() return TEST_GAME .. '/data/game' end
I.write_files = function() error('test must not write game files') end
require('entity_assets').begin = function() error('test must not write game assets') end
local mode = os.getenv('SHODAN_PARAMETER_TEST_PHASE') or 'setup'
local config = I.read(I.home .. '/config.txt')
if not config then
    local f = assert(io.open(I.home .. '/config.txt', 'wb'))
    f:write('changes on\nlang zh-Hans\nupdates off\ncache_clear_on_exit on\n'); f:close()
end
S.w, S.h = 1272, 1296
local gdi = ffi.load('gdi32'); S.dc = gdi.CreateCompatibleDC(nil); assert(S.dc ~= nil)
local info = ffi.new('host_bitmapinfo'); info.size = ffi.sizeof(info)
info.width, info.height, info.planes, info.bits = S.w, -S.h, 1, 32
local ptr = ffi.new('void *[1]'); local dib = gdi.CreateDIBSection(S.dc, info, 0, ptr, nil, 0); assert(dib ~= nil)
gdi.SelectObject(S.dc, dib); S.bits = ffi.cast('uint32_t *', ptr[0]); gdi.SetBkMode(S.dc, 1); gdi.SetTextAlign(S.dc, 24)
S.open = function() end; S.set_title = function() end; S.focused = function() return false end
S.cursor = function() return nil, nil end; S.key_down = function() return false end
S.message_box = function(message) error(message, 0) end
local real_loadfile = loadfile
local panel = app and app .. '/stat_editor.lua' or TEST_ROOT .. '/src/stat_editor_offline.lua'
loadfile = function(path, ...)
    if path == panel then
        local f = assert(io.open(path, 'rb')); local source = f:read('*a'); f:close()
        return loadstring(source .. [[
TEST_PARAMETERS={ui=ui,click=click,keyboard=keyboard,settings=settings,by_hash=by_hash,weapons=weapons,
 select=select_weapon,row_value=row_value,change=change,MOD=MOD,reset_row=reset_row,presets=presets,
 read=read_field,default_of=default_of}
]], '@' .. path)
    end
    return real_loadfile(path, ...)
end
local phase, changed, began = 0, 0, tonumber(ffi.C.GetTickCount64())
local function now() return tonumber(ffi.C.GetTickCount64()) end
local function index(page, row, favorite)
    for n, r in ipairs(page.rows) do
        if (r == row or r.parameter_source == row) and (r.parameter_favorite == true) == (favorite == true) then return n end
    end
    error('row is missing from visible parameter projection')
end
local function choose_menu(e, page, row, title, favorite)
    e.MOD.clipboard.right_click('row:' .. index(page, row, favorite), 800, 800)
    for n, item in ipairs(assert(e.ui.context_menu).items) do
        if item.label == title then e.click('context_item:' .. n); return end
    end
    error('missing parameter context action: ' .. title)
end
local function faction_regression(e)
    local faction = assert(e.by_hash.FFFFFFFB00000002)
    local global = assert(e.by_hash.FFFFFFFB000000FE)
    local health = assert(faction.by_id.all_health).row
    local global_health = assert(global.by_id.all_health).row
    local armor = assert(faction.by_id.all_armor).row
    e.select(faction)
    assert(faction.rows[1].parameter_hint, 'expected an empty favorites group on first faction selection')
    faction.enemy.targets = nil
    global.enemy.targets = nil
    e.change(health, 0, false, 2)
    local ok, why = pcall(e.MOD.enemy.faction_refresh)
    assert(ok, 'empty Favorites row crashed faction refresh: ' .. tostring(why))
    assert(not faction.enemy.targets.__favorite_hint and not global.enemy.targets.__favorite_hint,
        'presentation placeholders entered the faction target cache')
    local target
    for _, f in ipairs(faction.enemy.targets.all_health.list) do
        local d = e.default_of(f)
        if d and d > 0 and d < 1000000 then target = f; break end
    end
    assert(target, 'no faction health target')
    local baseline = e.default_of(target)
    assert(e.read(target) == baseline * 2)
    choose_menu(e, faction, health, '收藏')
    e.MOD.enemy.faction_refresh()
    assert(e.read(target) == baseline * 2, 'favorite applied the faction multiplier twice')
    e.select(global); choose_menu(e, global, global_health, '收藏')
    e.change(global_health, 0, false, 3); e.MOD.enemy.faction_refresh()
    assert(e.read(target) == baseline * 6, 'global/faction multipliers must compose once each')
    e.select(faction); choose_menu(e, faction, armor, '收藏')
    e.change(armor, 0, false, 3); e.MOD.enemy.faction_refresh()
    local armor_target
    for _, f in ipairs(faction.enemy.targets.all_armor.list) do
        local d = e.default_of(f)
        if d and d >= 0 and d < 100 then armor_target = f; break end
    end
    assert(armor_target and e.read(armor_target) == e.default_of(armor_target) + 3,
        'favorite applied the armor offset twice')
    local own_page, own_row
    for _, w in ipairs(e.weapons) do if w.enemy and not w.enemy.faction then
        for _, r in ipairs(e.MOD.parameter_rows(w)) do
            if #r.parts == 1 and r.parts[1].field == target then own_page, own_row = w, r; break end
        end
        if own_page then break end
    end end
    assert(own_page and own_row, 'no individually editable enemy health target')
    e.select(own_page); e.change(own_row, 0, false, baseline * 5); e.MOD.enemy.faction_refresh()
    assert(e.read(target) == baseline * 5, 'faction refresh overwrote the individual enemy override')
    e.reset_row(own_page, own_row); e.MOD.enemy.faction_refresh()
    assert(e.read(target) == baseline * 6, 'reset did not resume the global/faction multipliers')
    e.reset_row(faction, health); e.reset_row(faction, armor); e.reset_row(global, global_health)
    e.MOD.enemy.faction_refresh()
    assert(e.read(target) == baseline and e.read(armor_target) == e.default_of(armor_target))
    e.select(faction); choose_menu(e, faction, health, '取消收藏', true)
    choose_menu(e, faction, armor, '取消收藏', true)
    e.select(global); choose_menu(e, global, global_health, '取消收藏', true)
    assert(#H.diff() == 0, 'faction regression failed to restore native values')
end
local page, health, probe, before
S.pump = function()
    assert(now() - began < 90000, 'parameter host timeout')
    local state = rawget(_G, 'ShodanStatEditor')
    if state then
        assert(state.phase ~= 'gave_up', state.status)
        if state.phase == 'ready' and phase == 0 then
            local e = assert(TEST_PARAMETERS)
            page = assert(e.by_hash.FFFFFFF800000001); health = assert(page.by_id.health).row
            e.select(page); e.MOD.nav.sync()
            before = e.row_value(health); probe = e.MOD.parameters
            if mode == 'setup' then
                assert(not probe:get(page, health), 'setup needs fresh portable data')
                local writes = state.writes
                choose_menu(e, page, health, '收藏')
                assert(probe:get(page, health).favorite and state.writes == writes, 'presentation changed game-dirty state')
                assert(page.rows[1].parameter_source == health and page.rows[1].section_of() == '收藏')
                choose_menu(e, page, health, '自定义名称', true)
                assert(e.ui.parameter_name)
                S.push_typed(0x751F); S.push_typed(0x547D); S.push_typed(0x81EA); S.push_typed(0x5B9A); S.push_typed(0x4E49)
                e.keyboard(now() / 1000)
                assert(e.ui.parameter_name.text == '生命自定义', 'Chinese text input failed')
                phase, changed = 1, now()
            else
                local pref = assert(probe:get(page, health))
                assert(pref.favorite and pref.name == '生命自定义', 'restart lost portable parameter preferences')
                assert(page.rows[1].parameter_source == health)
                phase, changed = 3, now()
            end
        end
        if phase > 0 and now() - changed > 180 then S.version = S.version + 1 end
    end
    return phase < 4
end
S.present = function()
    local state = rawget(_G, 'ShodanStatEditor')
    if not state or state.phase ~= 'ready' or now() - changed < (phase == 1 and 1900 or 180) then return end
    local e = assert(TEST_PARAMETERS)
    if phase == 1 then
        assert(state.ui_errors == 0)
        local found = false; for _, r in ipairs(e.ui.regions) do if r.key == 'parameter_name:save' then found = true end end
        assert(found, 'name editor not drawn')
        S.save_bmp(TEST_WORK .. '/parameter-name-dialog.bmp')
        e.click('parameter_name:save'); assert(not e.ui.parameter_name)
        assert(probe:label(page, health) == '★ 生命自定义')
        -- Editing through the favorite hits the original field, including direct input and reset.
        local favorite = assert(page.rows[1]); e.change(favorite, 0, false, before + 1)
        assert(e.row_value(health) == before + 1)
        TEST_PRESETS_HELPER.save(e, page, 'favorite')
        e.select(page)
        local values = TEST_PRESETS_HELPER.values(e, page, 'favorite')
        assert(#values == 1 and values[1].id == 'health', 'favorite duplicated or renamed the preset field ID')
        e.reset_row(page, favorite); assert(e.row_value(health) == before)
        TEST_PRESETS_HELPER.load(e, page, 'favorite'); assert(e.row_value(health) == before + 1)
        e.reset_row(page, favorite); e.select(page)
        -- Clearing the game-edit cache cannot remove presentation preferences.
        e.click('cache_clear'); e.click('cache_clear')
        assert(probe:get(page, health).name == '生命自定义')
        phase, changed = 2, now()
    elseif phase == 2 then
        assert(state.ui_errors == 0)
        S.save_bmp(TEST_WORK .. '/parameter-favorites.bmp')
        -- Removing a favorite while its row is selected must preserve the name and selection.
        choose_menu(e, page, health, '取消收藏', true)
        assert(not probe:get(page, health).favorite and probe:get(page, health).name)
        assert(page.rows[e.ui.row] == health)
        choose_menu(e, page, health, '恢复默认名称')
        assert(not probe:get(page, health))
        choose_menu(e, page, health, '自定义名称'); e.ui.parameter_name.text = 'cancelled'
        e.click('parameter_name:cancel'); assert(not probe:get(page, health))
        choose_menu(e, page, health, '收藏'); choose_menu(e, page, health, '自定义名称', true)
        e.ui.parameter_name.text = '生命自定义'; e.click('parameter_name:save')
        phase, changed = 3, now()
    elseif phase == 3 then
        assert(state.ui_errors == 0 and #H.diff() == 0, 'presentation test left native game values changed')
        local health_page
        for _, w in ipairs(e.MOD.health_components.pages) do if w.health_full and w.hash ~= page.hash then health_page = w; break end end
        assert(health_page)
        e.select(health_page)
        assert(health_page.rows[1].parameter_favorite and not health_page.rows[1].parameter_hint,
            'Health favorites must be available above its closed body/part groups on another entity')
        assert(probe:label(health_page, health_page.rows[1]) == '★ 生命自定义', 'component name/favorite did not follow the native field')
        -- Load a lazy weapon group, checking favorites are scoped inside its component.
        local weapon, group
        for _, w in ipairs(e.weapons) do
            for _, g in ipairs(w.component_groups or {}) do if g.spec and not g.loaded then weapon, group = w, g; break end end
            if weapon then break end
        end
        assert(weapon and group)
        e.select(weapon); assert(not group.loaded, 'favorites forced unopened components')
        e.click('comp_toggle:' .. group.type); e.MOD.parameter_refresh(weapon)
        assert(group.loaded and weapon.rows[1].parameter_hint and weapon.rows[1].component == group.type)
        assert(weapon.rows[1].section_of() == '收藏')
        faction_regression(e)
        phase = 4
    end
end
SHODAN_OFFLINE_LANG = 'zh-Hans'; arg = { [1] = panel }
assert(loadfile(app and app .. '/host.lua' or TEST_ROOT .. '/offline/host.lua'))()
assert(phase == 4)
loadfile = real_loadfile
assert(I.read(probe.path):find('生命自定义', 1, true), 'close cleared portable parameter records')
gdi.DeleteDC(S.dc)
print('PASS: real host ' .. mode .. ', favorites/name/Chinese input/persistence; empty faction favorites, single multiplier/offset application, global composition, individual override/reset; no live writes')
