-- A dependency failure must stop our job even when the shared bus swallows errors.
-- Run with tests/run_lua.py --isolated-profile --work <temporary directory>.
assert(TEST_WORK and os.getenv('LOCALAPPDATA'):match('[/\\]profile%-root$'),
    'run this test with --isolated-profile --work <temporary directory>')
require('install').mkdirs(os.getenv('LOCALAPPDATA'))
local S = require('engine_shim')
SHODAN_OFFLINE = true
stingray = S.engine()
update = function() end
local f = assert(io.open(TEST_ROOT .. '/src/stat_editor_offline.lua', 'rb'))
local source = f:read('*a'); f:close()
source = source .. [[
TEST_STARTUP = {
    state = state, fields = fields,
    job = BUS.jobs[MOD.global],
    fail_in = function(phase)
        state.phase = phase
        local function fail()
            TEST_STARTUP.attempts = TEST_STARTUP.attempts + 1
            -- Real rows retain their pages through the shared field's users list.
            local page = {rows = {}, by_id = {}}
            add_row(page, 'Fixture', 'value', 'Fixture', 'u32',
                {part('value', 1, 0, 'u32', 100)}, 0, 100, 1, 10)
            require('__startup_failure_fixture__')
        end
        if phase == 'building' then state.build_some = fail
        elseif phase == 'preparing' then prepare = fail; progress = {next = 1}
        else KINDS[TYPES.throwable].update_launch = fail end
    end,
    has_progress = function() return progress ~= nil end,
}
]]
assert(loadstring(source, '@' .. TEST_ROOT .. '/src/stat_editor_offline.lua'))()
local E = assert(TEST_STARTUP)
package.preload.__startup_failure_fixture__ = function()
    error('injected missing runtime module')
end
local function references()
    local n = 0
    for _,field in pairs(E.fields) do n = n + #field.users end
    return n
end
for _,phase in ipairs({'building', 'preparing', 'ready'}) do
    E.attempts = 0
    package.loaded.__startup_failure_fixture__ = nil
    E.fail_in(phase)
    assert(pcall(E.job), 'our job must handle its own failure')
    assert(E.state.phase == 'gave_up')
    assert(E.state.status:find('injected missing runtime module', 1, true), E.state.status)
    assert(E.state.failure:find('stack traceback:', 1, true))
    assert(not E.has_progress(), 'failed initialization must release its progress')
    local before = references()
    collectgarbage('collect')
    local heap = collectgarbage('count')
    for _ = 1,1000 do assert(pcall(E.job)) end
    collectgarbage('collect')
    assert(E.attempts == 1, 'a failed job retried and retained more component pages')
    assert(references() == before, 'field users grew after initialization failed')
    assert(collectgarbage('count') < heap + 64, 'failed job heap did not stay bounded')
end
local log = assert(io.open(require('install').logs .. '/SHODANStatEditor.log', 'rb'))
local text = log:read('*a'); log:close()
assert(text:find('injected missing runtime module', 1, true))
assert(text:find('stack traceback:', 1, true))
print('PASS: building, preparing and ready failures stop after one attempt; 1000 subsequent frames retain no extra pages; traceback is logged')
