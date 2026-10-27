-- SHODAN Stat Editor Offline: Stat Editor's own panel (stat_editor.lua, the in-game mod) in a desktop window,
-- editing the game's data files instead of the running game. The files are decrypted into memory as the game
-- holds them, the panel finds and edits them there, and Install writes the changed ones into the game folder.
-- host.lua [stat_editor.lua]
local here = (debug.getinfo(1, 'S').source:match('^@(.*[/\\])') or './')
package.path = here .. '?.lua;' .. package.path

local ffi = require('ffi')
local shim = require('engine_shim')
local G = require('gamedata')
local D = require('hostdata')
local I = require('install')
local U = require('update')
local Demo = require('demolition')
local DemoPanel = require('demolition_panel')
local DemoBridge = require('demolition_bridge')
local UnitAliases = require('unit_aliases')
local EntityAssets = require('entity_assets')
local LOCAL_ENTITY_EXTENSION = true

pcall(ffi.cdef, 'uint64_t GetTickCount64(void);')
local function clock() return tonumber(ffi.C.GetTickCount64()) / 1000 end
local log_file = nil
local function log(text)
    if not log_file then
        I.mkdirs(I.logs)
        log_file = io.open(I.logs .. '/SHODANStatEditorHost.log', 'w')
        if not log_file then log_file = false end
    end
    if log_file then log_file:write(os.date('%H:%M:%S '), text, '\n'); log_file:flush() end
end

local BACK = { 255, 12, 15, 19 }
local RED = { 255, 255, 72, 60 }   -- the Enemy Editor's (editor.lua's red)
local GOLD, WHITE, MUTED, WARN, GOOD = { 255, 255, 213, 0 }, { 255, 238, 242, 246 }, { 255, 153, 171, 184 },
                                        { 255, 255, 150, 60 }, { 255, 120, 220, 140 }

local function centred(text, y, size, c)
    shim.text(text, (shim.w - shim.text_width(text, size)) / 2, y, size, c)
end

-- a screen with a few lines of text (loading, problems)
local function screen(lines)
    shim.fill(0, 0, shim.w, shim.h, BACK)
    local s = shim.h / 1080
    local y = shim.h * 0.42
    for k, line in ipairs(lines) do
        local size = (k == 1 and 34 or 20) * s
        centred(line, y, size, k == 1 and GOLD or MUTED)
        y = y + size * 1.8
    end
    shim.present()
end

local function fatal(text)
    log('stopped: ' .. text)
    shim.message_box(text, 0x10)
    os.exit(1)
end

-- ---------------------------------------------------------------- start
-- where the window was when it last closed: its top left (window.txt: x y)
local PLACE = I.home .. '/window.txt'
local function saved_place()
    local f = io.open(PLACE, 'r')
    local text = f and f:read('*a') or ''
    if f then f:close() end
    local x, y = text:match('^(%-?%d+) (%-?%d+)')
    return x and { tonumber(x), tonumber(y) } or nil
end

local function main()
    shim.open('SHODAN Stat Editor Offline', saved_place())
    shim.pump()
    local migrated = I.migrate()
    if migrated then log('copied ' .. migrated .. ' files from the CowboyBingus folder') end
    screen({ 'SHODAN Stat Editor Offline', 'Looking for Helldivers 2...' })
    local exe_dir = here:gsub('[/\\]app[/\\]$', ''):gsub('[/\\]$', '')
    local game = I.find_game(exe_dir)
    if not game then
        fatal('Helldivers 2 was not found.\n\nWrite the path of its folder (the one holding "data") into\n'
              .. I.home:gsub('/', '\\') .. '\\game folder.txt\nand start again.')
    end
    log('game: ' .. game)
    log('hash search: ' .. (G.native and 'native, every core' or 'Lua (shodan_hash.dll not found)'))
    screen({ 'SHODAN Stat Editor Offline', 'Reading the game\'s data files...' })
    shim.pump()
    local originals, ours, problems, count = I.originals(game)
    if count == 0 then fatal('No game data files in ' .. game) end
    for _, p in ipairs(D.load(game, originals)) do problems[#problems + 1] = p end
    -- The new authoring model retains serialized snapshots. The process-wide table
    -- scanner must never mistake those immutable Lua strings for writable host tables.
    local live_headers = {}
    for _,file in pairs(D.files) do
        local base=tonumber(ffi.cast('uintptr_t',file.p))
        for _,header in ipairs(G.headers(file.p,file.n)) do live_headers[base+header.at]=true end
    end
    rawset(_G,'SHODAN_OFFLINE_TABLE_ADDRESS',function(address)return live_headers[address]==true end)
    for _, p in ipairs(problems) do log('problem: ' .. p) end
    local loaded = 0
    for _ in pairs(D.files) do loaded = loaded + 1 end
    log(string.format('%d of %d files loaded, %d installed by an earlier install', loaded, count,
        (function() local n = 0; for _ in pairs(ours) do n = n + 1 end return n end)()))
    if loaded == 0 then
        fatal('None of the game\'s data files could be read:\n\n' .. table.concat(problems, '\n', 1, math.min(#problems, 8))
              .. '\n\nVerify the game files in Steam and start again.')
    end
    if #problems > 0 then
        shim.message_box('Some of the game\'s data files are not as this editor expects; their stats cannot be edited:\n\n'
                         .. table.concat(problems, '\n', 1, math.min(#problems, 10))
                         .. '\n\nIf another tool changed them, verify the game files in Steam.', 0x30)
    end

    -- ------------------------------------------------------------ the editor
    screen({ 'SHODAN Stat Editor Offline', 'Finding the stats...' })
    rawset(_G, 'SHODAN_OFFLINE', true)
    -- the panel's first language (until one is chosen in Settings): Windows' display language, if translated
    pcall(ffi.cdef, 'uint16_t GetUserDefaultUILanguage(void);')
    local id = ffi.C.GetUserDefaultUILanguage()
    local primary, sub = id % 1024, math.floor(id / 1024)
    if rawget(_G, 'SHODAN_OFFLINE_LANG') == nil then rawset(_G, 'SHODAN_OFFLINE_LANG', primary == 0x04 and ((sub == 2 or sub == 4) and 'zh-Hans' or 'zh-Hant')
                                      or primary == 0x19 and 'ru' or nil) end
    stingray = shim.engine()
    function update(dt) end
    local editor = arg and arg[1] or here .. 'stat_editor.lua'
    local chunk, why = loadfile(editor)
    if not chunk then fatal('Could not load ' .. editor .. ':\n' .. tostring(why)) end
    local ok, err = pcall(chunk)
    if not ok then fatal('Stat Editor did not start:\n' .. tostring(err)) end
    local state = rawget(_G, 'ShodanStatEditor')
    if type(state) ~= 'table' then fatal('Stat Editor did not start (no state).') end
    local build = U.build(here)   -- app/build.txt: version, commit, channel
    shim.set_title('SHODAN Stat Editor Offline v' .. tostring(state.version) .. ' | Entity Demolition Unified'
                   .. (build.channel == 'dev' and build.commit and ' (dev ' .. build.commit:sub(1, 7) .. ')' or '')
                   .. (build.built and ' | build ' .. build.built or ''))   -- (build_release.bat: when it was packed)
    -- the host's own text in the panel's language, drawn with its font
    local function tr(text) return type(state.tr) == 'function' and state.tr(text) or text end
    if type(state.lang) == 'function' then shim.lang = state.lang end

    local demolition, demolition_model, demolition_error, demolition_on
    local function source_plain(cipher)
        assert(cipher, 'required entity data file is missing')
        local p,n = G.open_sealed(cipher)
        assert(p, 'required entity data file could not be decrypted')
        G.clear_correction(p,n)
        local bytes = ffi.string(p,n);G.free(p);return bytes
    end
    local demo_ok, demo_why = pcall(function()
        demolition_model = Demo.new(source_plain(D.files['generated_entities.dl_bin'] and D.files['generated_entities.dl_bin'].cipher),
            source_plain(D.files['generated_destruction_settings.dl_bin'] and D.files['generated_destruction_settings.dl_bin'].cipher),
            source_plain(I.read(game .. '/dl_library.dl_typelib')),Demo.read_names(here .. 'entity_names.tsv'))
        I.mkdirs(I.home)
        demolition = DemoPanel.new(demolition_model,{path=I.home .. '/entity_demolition.txt',lang=shim.lang,tr=tr,
            enabled=function()return type(state.entity_demolition_enabled)~='function'or state.entity_demolition_enabled()end,
            changed=function()
                state.writes=state.writes+1
                if type(state.sync_demolition)=='function'then state.sync_demolition()end
            end})
        rawset(_G,'SHODAN_DEMOLITION_BRIDGE',DemoBridge.new(demolition,{config_path=I.home..'/config.txt',log=log}))
        rawset(_G,'SHODAN_DEMOLITION_UNIT',function(key)
            local rec=demolition_model.units[key]
            return rec and demolition_model.entities:sub(rec.offset+1,rec.offset+8) or nil
        end)
        log(string.format('entity demolition: %d targets catalogued',#demolition_model.targets))
    end)
    if not demo_ok then demolition_error=tostring(demo_why);log('entity demolition unavailable: '..demolition_error) end

    -- ------------------------------------------------------------ the host's bar (below the panel)
    local bar = { hover = nil, message = nil, tone = MUTED, busy = nil, base = nil, buttons = {} }
    local function layout()
        local s = shim.h / 1080
        local y0, y1 = 1038 * s, 1072 * s
        bar.buttons = {
            { key = 'install', label = 'Install into the game', x0 = 30 * s, x1 = 290 * s, y0 = y0, y1 = y1 },
            { key = 'restore', label = 'Restore the game\'s files', x0 = 302 * s, x1 = 562 * s, y0 = y0, y1 = y1 },
        }
        if bar.release then
            local x1 = shim.w - 30 * s
            bar.buttons[3] = { key = 'update', label = 'Update to ' .. bar.release.label, x0 = x1 - 170 * s, x1 = x1,
                               y0 = 9 * s, y1 = 41 * s, gold = true }   -- top right, in the tagline's place
        end
        -- the titles (paint_bar): the editor's pages (the layout document's, state.nav_pages; the Enemy Editor's
        -- page red), then Entity Demolition; an editor without pages: Stat Editor, then Enemy Editor. The labels
        -- shrink together until the row fits the window (and the update button, when there is one).
        local x = 30 * s
        bar.titles = {}
        local items = {}
        local pages = type(state.nav_pages) == 'function' and state.nav_pages() or {}
        for _, p in ipairs(pages) do
            items[#items + 1] = { key = 'page:' .. p.id, label = p.label, color = p.enemy and RED or GOLD }
        end
        if #items == 0 then
            items[1] = { key = 'title_stat', label = 'SHODAN Stat Editor', color = GOLD }
            if type(state.switch_editor) == 'function' then
                items[2] = { key = 'title_enemy', label = 'SHODAN Enemy Editor', color = RED }
            end
        end
        items[#items + 1] = { key = 'title_demolition', color = { 255, 103, 210, 220 },
                              label = demolition and demolition:tr('title') or 'Entity Demolition' }
        local size, pad, gap = 17 * s, 10 * s, 6 * s
        local room = shim.w - 60 * s - (bar.release and 182 * s or 0)
        local function total()
            local t = gap * (#items - 1)
            for _, it in ipairs(items) do t = t + shim.text_width(it.label, size, true) + 2 * pad end
            return t
        end
        while size > 11 * s and total() > room do size, pad = size - 0.5 * s, math.max(5 * s, pad - 0.25 * s) end
        for _, it in ipairs(items) do
            local w = shim.text_width(it.label, size, true) + 2 * pad
            bar.titles[#bar.titles + 1] = { key = it.key, label = it.label, color = it.color, size = size, pad = pad,
                                            x0 = x, x1 = x + w, y0 = 6 * s, y1 = 42 * s }
            x = x + w + gap
        end
        bar.s, bar.h, bar.lang = s, shim.h, shim.lang()
    end
    layout()

    local function installed_count() local n = 0; for _, v in pairs(ours) do if v then n = n + 1 end end return n end

    local function status()
        if bar.busy then return bar.busy, WARN end
        if bar.message then return bar.message, bar.tone end
        if state.phase ~= 'ready' then return 'Finding the stats...', MUTED end
        local n = installed_count()
        local dirty = bar.base and state.writes ~= bar.base
        if dirty and n == 0 then return 'Your values are not in the game yet: close the game, then Install.', WARN end
        if dirty then return 'Changed since the last install: Install to put it in the game.', WARN end
        if n > 0 then return 'Your values are installed (' .. n .. ' game files). Close the game before installing.', GOOD end
        return 'The game\'s own files are in place. Close the game, then Install to play with your values.', MUTED
    end

    local function paint_bar()
        local s = bar.s
        shim.fill(0, 1032 * s, shim.w, shim.h, BACK)
        shim.fill(0, 0, shim.w, 46 * s, BACK)
        -- the two editors' titles, as buttons: the one shown bright in a box of its colour, the other dimmed
        -- (brighter under the mouse); a click swaps
        local enemy = type(state.enemy_on) == 'function' and state.enemy_on()
        local page = type(state.nav_page) == 'function' and state.nav_page()
        local active_title = demolition_on and 'title_demolition' or page and ('page:' .. page)
                             or enemy and 'title_enemy' or 'title_stat'
        local function toward_back(c, k)
            return { 255, math.floor(BACK[2] + (c[2] - BACK[2]) * k), math.floor(BACK[3] + (c[3] - BACK[3]) * k),
                     math.floor(BACK[4] + (c[4] - BACK[4]) * k) }
        end
        for _, t in ipairs(bar.titles) do
            local on = t.key == active_title
            local hovered = bar.hover == t.key and not on
            local c = on and t.color or toward_back(t.color, hovered and 0.65 or 0.4)
            local fill = on and toward_back(t.color, 0.3) or hovered and { 255, 40, 48, 58 } or { 255, 24, 29, 36 }
            local edge = on and t.color or hovered and toward_back(t.color, 0.8) or { 255, 70, 82, 94 }
            local e = math.max(1, math.floor(2 * s + 0.5))
            shim.fill(t.x0, t.y0, t.x1, t.y1, fill)
            shim.fill(t.x0, t.y0, t.x1, t.y0 + e, edge); shim.fill(t.x0, t.y1 - e, t.x1, t.y1, edge)
            shim.fill(t.x0, t.y0, t.x0 + e, t.y1, edge); shim.fill(t.x1 - e, t.y0, t.x1, t.y1, edge)
            shim.flush()
            shim.text(t.label, t.x0 + t.pad, (t.y0 + t.y1) / 2 + t.size * 0.35, t.size, c, true)
        end
        local t = (shim.lang()=='zh-Hans' or shim.lang()=='zh-Hant') and '拆毁设置已统一' or 'Unified demolition'
        if not bar.release then
            -- smaller where it would run into the titles (a longer translation)
            local last = bar.titles[#bar.titles]
            local room, size = shim.w - 30 * s - (last and last.x1 + 16 * s or 0), 15 * s
            while size > 10 * s and shim.text_width(t, size) > room do size = size - 0.5 * s end
            -- (left out when the pages take the whole row)
            if shim.text_width(t, size) <= room then
                shim.text(t, shim.w - 30 * s - shim.text_width(t, size), 31 * s, size, MUTED)
            end
        end
        for _, b in ipairs(bar.buttons) do
            local hovered = bar.hover == b.key and not bar.busy
            shim.fill(b.x0, b.y0, b.x1, b.y1, hovered and { 255, 52, 66, 80 } or { 255, 28, 34, 42 })
            local edge = hovered and GOLD or { 255, 70, 82, 94 }
            local e = math.max(1, math.floor(2 * s + 0.5))
            shim.fill(b.x0, b.y0, b.x1, b.y0 + e, edge); shim.fill(b.x0, b.y1 - e, b.x1, b.y1, edge)
            shim.fill(b.x0, b.y0, b.x0 + e, b.y1, edge); shim.fill(b.x1 - e, b.y0, b.x1, b.y1, edge)
            shim.flush()
            local size, label = 16 * s, tr(b.label)
            while size > 10 * s and shim.text_width(label, size) > b.x1 - b.x0 - 12 * s do size = size - 0.5 end
            shim.text(label, (b.x0 + b.x1 - shim.text_width(label, size)) / 2, (b.y0 + b.y1) / 2 + size * 0.35, size,
                      b.gold and GOLD or WHITE)
        end
        local text, tone = status()
        text = tr(text)
        local x = 576 * s
        local size = 14 * s
        local limit = shim.w - 30 * s - x
        while size > 9 * s and shim.text_width(text, size) > limit do size = size - 0.5 end
        shim.text(text, x, 1055 * s + size * 0.35, size, tone)
    end

    local function paint()
        if demolition_on and demolition then
            demolition:draw(shim)
        elseif demolition_on then
            screen({'Entity demolition unavailable',demolition_error or 'Required game data is missing'})
        elseif state.phase == 'ready' then
            shim.paint_guis(BACK)
        else
            shim.fill(0, 0, shim.w, shim.h, BACK)
            centred(tr('Finding the stats...'), shim.h * 0.45, 30 * bar.s, GOLD)
            centred(tostring(state.status or ''), shim.h * 0.45 + 40 * bar.s, 18 * bar.s, MUTED)
        end
        paint_bar()
        shim.present()
    end

    local function say(text, tone) bar.message, bar.tone = text, tone or MUTED end

    local function busy(text)
        bar.busy = text
        paint()
        shim.pump()
    end

    -- ------------------------------------------------------------ install / restore
    local function commit_active()
        local ok,why=true,nil
        if demolition_on and demolition then ok,why=demolition:commit()
        elseif type(state.commit_value)=='function'then ok,why=state.commit_value()end
        if not ok then say(why or'Finish the current value before switching pages or installing.',WARN)end
        return ok
    end
    local function install()
        if not commit_active()then return end
        if I.game_running() then say('Helldivers 2 is running: close it, then Install.', WARN); return end
        busy('Installing: finding what changed...')
        local changes = D.diff()
        local stacked, why_not = D.stack(changes, state.stacks and state.stacks(), log, state.own_off and state.own_off())
        if not stacked then
            for _, c in ipairs(changes) do G.free(c.plain) end
            bar.busy = nil
            log('install stopped: passive stacking: ' .. tostring(why_not))
            say('Not installed: the armor passives could not be stacked (' .. tostring(why_not) .. '). Nothing was changed.', WARN)
            return
        end
        local coded
        coded, why_not = D.codes(changes, state.codes and state.codes(), log)
        if not coded then
            for _, c in ipairs(changes) do G.free(c.plain) end
            bar.busy = nil
            log('install stopped: stratagem codes: ' .. tostring(why_not))
            say('Not installed: the stratagem codes could not be set (' .. tostring(why_not) .. '). Nothing was changed.', WARN)
            return
        end
        local writes, made, back = {}, 0, 0
        local asset_writes, asset_report = {}, {}
        if demolition then
            busy('Preparing independent entity demolition...')
            local success, why = pcall(function()
                local enabled = type(state.entity_demolition_enabled)~='function' or state.entity_demolition_enabled()
                local aliases,result = demolition_model:changes(changes,demolition:overrides(enabled),D)
                if result then log(string.format('entity demolition: %d isolated targets, %d private templates',#result.report,
                    result.template_count-result.original_template_count)) end
                asset_writes,asset_report = UnitAliases.prepare(aliases,{game=game,
                    cache=I.home..'/entity-resource-cache/'..tostring(math.floor(clock()*1000)),
                    filediver=UnitAliases.find_filediver(here),owned=EntityAssets.owned(),
                    log=function(text)log(text);busy(text)end,pump=function()return shim.pump()end})
            end)
            if not success then
                for _,c in ipairs(changes)do G.free(c.plain)end
                bar.busy=nil;log('entity demolition preparation failed: '..tostring(why))
                say('Not installed: '..tostring(why),WARN);return
            end
        end
        for k, c in ipairs(changes) do
            busy(string.format('Installing: preparing %s (%d of %d)...', c.name, k, #changes))
            local sealed, why = D.build(c, function(text) log(c.name .. ': ' .. text); shim.pump() end)
            if not sealed then
                for j = k + 1, #changes do G.free(changes[j].plain) end
                bar.busy = nil
                log('install stopped: ' .. c.name .. ': ' .. tostring(why))
                say('Not installed: ' .. c.name .. ' could not be prepared (' .. tostring(why) .. '). Nothing was changed.', WARN)
                return
            end
            writes[c.name], made = sealed, made + 1
        end
        for name, mine in pairs(ours) do
            if mine and not writes[name] then writes[name], back = originals[name], back + 1 end
        end
        if not next(writes) and not next(asset_writes) and not next(EntityAssets.owned()) then
            bar.busy, bar.base = nil, state.writes
            say('Nothing to install: your values are the game\'s own.', GOOD)
            return
        end
        busy('Installing: writing the files...')
        local valid,asset_transaction = pcall(EntityAssets.begin,game,asset_writes)
        if not valid then bar.busy=nil;say('Not installed: '..tostring(asset_transaction),WARN);return end
        local assets_ok,assets_why=asset_transaction:activate()
        if not assets_ok then bar.busy=nil;say('Not installed: '..tostring(assets_why),WARN);return end
        local done, why = I.write_files(game, writes, originals)
        bar.busy = nil
        if not done then
            local rolled,rollback_why=asset_transaction:rollback()
            if not rolled then why=tostring(why)..'; entity asset rollback failed: '..tostring(rollback_why)end
            log('install failed: ' .. tostring(why))
            say('Not installed: ' .. tostring(why), WARN)
            return
        end
        local recorded,record_why=asset_transaction:commit()
        if not recorded then log('entity assets remain in recoverable pending ownership: '..tostring(record_why))end
        log(string.format('entity resource patches installed: %d source triads',#asset_report))
        for name, data in pairs(writes) do ours[name] = data ~= originals[name] end
        bar.base = state.writes
        log(string.format('installed: %d changed, %d back to the original', made, back))
        say(string.format('Installed (%d game files changed%s). Start the game to play with your values.', made,
            back > 0 and ', ' .. back .. ' back to the original' or ''), GOOD)
    end

    local function restore()
        if I.game_running() then say('Helldivers 2 is running: close it, then restore.', WARN); return end
        local writes = {}
        for name, mine in pairs(ours) do if mine then writes[name] = originals[name] end end
        if not next(writes) and not next(EntityAssets.owned()) then say('The game\'s own files are already in place.', GOOD); return end
        busy('Restoring the game\'s files...')
        local names = {}
        for name in pairs(writes) do names[#names + 1] = name end
        local valid,asset_transaction=pcall(EntityAssets.begin,game,{})
        if not valid then bar.busy=nil;say('Not restored: '..tostring(asset_transaction),WARN);return end
        local activated,asset_why=asset_transaction:activate()
        if not activated then bar.busy=nil;say('Not restored: '..tostring(asset_why),WARN);return end
        local done, why = I.write_files(game, writes, originals, true)
        bar.busy = nil
        if not done then asset_transaction:rollback();say('Not restored: ' .. tostring(why), WARN); return end
        asset_transaction:commit()
        -- files another tool changed since: left as they are (theirs now); files another mod had changed before
        -- this editor: back to that mod's version, which Steam's file check replaces (issue #90)
        local modded = 0
        for _, name in ipairs(names) do
            ours[name] = false
            if writes[name] and D.modded[name] then modded = modded + 1 end
        end
        for _, name in ipairs(why) do log('restore skipped ' .. name .. ': another tool changed it since') end
        bar.base = nil
        log('restored the originals')
        say('The game\'s files are back as they were before this editor. Your values stay saved here (Install puts them in again).'
            .. (modded > 0 and string.format(' %d of them still hold another mod\'s changes: Steam\'s "Verify integrity of game files" puts back the game\'s own.', modded) or ''), GOOD)
    end

    -- ------------------------------------------------------------ updates (update.lua)
    local exe_dir = exe_dir
    local function update_program()
        local release = bar.release
        busy('Updating: downloading ' .. release.label .. '...')
        local zip = U.dir .. '/' .. release.name
        local job, why = U.fetch(release.url, zip)
        local done = nil
        if job then
            repeat
                if not shim.pump() then bar.busy = nil; return false end
                shim.sleep(20)
                done, why = U.poll(job)
            until done ~= nil
        end
        if not done then
            bar.busy = nil
            log('update: download failed: ' .. tostring(why))
            say('Update failed: ' .. tostring(why) .. '. The release page has it: ' .. U.PAGE, WARN)
            return false
        end
        busy('Updating: installing ' .. release.label .. '...')
        local exe, problem = U.install(zip, exe_dir, log)
        bar.busy = nil
        if not exe then
            log('update: not installed: ' .. tostring(problem))
            say('Update failed: ' .. tostring(problem) .. '. Nothing was changed.', WARN)
            return false
        end
        log('update: ' .. release.label .. ' installed, restarting: ' .. exe)
        U.note(release.label)
        bar.restart = exe
        return true
    end

    -- ------------------------------------------------------------ the frame loop
    local painted, was_down, armed, said_ready = nil, false, nil, false
    local last = clock()
    while shim.pump() do
        local now = clock()
        if demolition_on and demolition then demolition:update(shim)
        else update(math.min(0.1, now - last)) end
        last = now
        -- moved onto another screen: sized for that one; another language: the pages' names again
        if bar.h ~= shim.h or bar.lang ~= shim.lang() then layout() end
        if state.phase == 'ready' and not said_ready then
            said_ready = true
            if demolition and type(state.demolition_labels)=='function' then
                local labels=state.demolition_labels()
                for _,target in ipairs(demolition_model.targets)do target.name=labels[target.hash]or target.name end
                table.sort(demolition_model.targets,function(a,b)return a.name:lower()<b.name:lower()end)
                demolition:refilter()
            end
            bar.base = installed_count() > 0 and state.writes or nil
            log(string.format('ready: %s weapons, %s values applied, %s refused', tostring(state.weapons),
                tostring(state.applied), tostring(state.refused)))
            local stacks = state.stacks and state.stacks() or {}
            local own_off = state.own_off and state.own_off() or {}
            if installed_count() == 0 and ((state.applied or 0) > 0 or next(stacks) or next(own_off)) then bar.base = -1 end
            if I.game_running() then say('Helldivers 2 is running: you can edit, but close it before you Install.', WARN) end
            local updated = U.cleanup()
            if updated then say('Updated to ' .. updated .. '.', GOOD) end
        end
        -- updates: asked at start, and again when Settings > Update channel changes
        local channel = type(state.update_channel) == 'function' and state.update_channel() or 'releases'
        -- This source extension must not be silently replaced by an upstream binary update.
        if not LOCAL_ENTITY_EXTENSION and said_ready and U.available and channel ~= bar.channel and not U.checking and not bar.restart then
            bar.channel = channel
            if bar.release then bar.release = nil; layout() end
            U.check(channel)
        end
        if U.checking then
            local current = { version = state.version, commit = build.commit }
            local release = U.check_poll(current)
            if release and bar.channel ~= U.channel then release = nil end   -- the channel changed meanwhile
            if release then
                bar.release = release
                layout()
                log('update: ' .. release.label .. ' is available (' .. release.name .. ')')
                -- Settings > Updates: Automatic
                if type(state.updates) == 'function' and state.updates() == 'auto' and update_program() then break end
            elseif release == false then
                log('update: nothing newer on ' .. tostring(U.channel) .. ' than v' .. tostring(current.version)
                    .. (current.commit and ' (' .. current.commit:sub(1, 7) .. ')' or ''))
            end
        end
        -- the bar's buttons
        local x, y = nil, nil
        if shim.focused() then x, y = shim.cursor() end
        local hover = nil
        for _, b in ipairs(bar.buttons) do
            if x and x >= b.x0 and x < b.x1 and y >= b.y0 and y < b.y1 then hover = b.key end
        end
        if #bar.titles > 1 then
            for _, b in ipairs(bar.titles) do
                if x and x >= b.x0 and x < b.x1 and y >= b.y0 and y < b.y1 then hover = b.key end
            end
        end
        bar.hover = hover
        local down = shim.focused() and shim.key_down(0x01)
        if down and not was_down then armed = hover end
        if not down and was_down and armed and armed == hover and state.phase == 'ready' then
            bar.message = nil
            if hover == 'install' then install() elseif hover == 'restore' then restore()
            elseif hover == 'update' and update_program() then break
            elseif hover == 'title_demolition' then
                if commit_active()then
                if type(state.release_input)=='function' then state.release_input() end
                demolition_on=true
                if demolition then demolition:activate(shim)end
                end
            elseif hover == 'title_stat' or hover == 'title_enemy' then
                if commit_active()then demolition_on=false;state.switch_editor(hover == 'title_enemy')end
            elseif hover and hover:sub(1, 5) == 'page:' then   -- one of the editor's pages
                if commit_active() then demolition_on = false; state.nav_open(hover:sub(6)) end
            end
            armed = nil
        end
        was_down = down
        local text = status()
        local signature = table.concat({ shim.version, state.phase, tostring(state.status), tostring(hover), text,
                                         tostring(type(state.nav_page) == 'function' and state.nav_page() or ''),
                                         shim.lang(), bar.release and bar.release.label or '',tostring(demolition_on),
                                         demolition and demolition.version or 0 }, '|')
        if signature ~= painted then
            painted = signature
            paint()
        end
        shim.sleep(state.phase == 'ready' and 10 or 1)
    end
    if shim.place then
        I.mkdirs(I.home)
        local f = io.open(PLACE, 'w')
        if f then f:write(shim.place[1], ' ', shim.place[2], '\n'); f:close() end
    end
    -- the editor saves its values a moment after a change
    local stop = clock() + 1.5
    while clock() < stop do update(0.05); shim.sleep(20) end
    if bar.restart then
        local go = true
        if go and not U.launch(bar.restart) then
            shim.message_box('Updated. Start ' .. bar.restart:gsub('/', '\\') .. ' again.', 0x40)
        end
    end
    log('closed')
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    log('error: ' .. tostring(err))
    shim.message_box('SHODAN Stat Editor Offline stopped:\n\n' .. tostring(err), 0x10)
end
